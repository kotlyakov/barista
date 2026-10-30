// Export existing VISUAL-002/v9 SVG geometry, without redrawing approved shapes.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const [source,output]=process.argv.slice(2);
if(!source||!output)throw Error('Usage: node tools/art/export_approved_rigs.mjs SOURCE_SNAPSHOT OUTPUT');
const {createActors,EMOTIONS}=await import(pathToFileURL(resolve(source,'actors.mjs')));
class SvgNode {
 constructor(tag){this.tag=tag;this.attrs={};this.children=[];}
 setAttribute(k,v){this.attrs[k]=String(v);}
 getAttribute(k){return this.attrs[k]??null;}
 appendChild(n){n.remove();this.children.push(n);n.parent=this;return n;}
 insertBefore(n,b){n.remove();this.children.splice(this.children.indexOf(b),0,n);n.parent=this;}
 remove(){if(this.parent){this.parent.children=this.parent.children.filter(n=>n!==this);this.parent=null;}}
}
globalThis.document={createElementNS:(_,tag)=>new SvgNode(tag)};
const escape=v=>String(v).replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;');
const xml=n=>`<${n.tag}${Object.entries(n.attrs).map(([k,v])=>` ${k}="${escape(v)}"`).join('')}>${n.children.map(xml).join('')}</${n.tag}>`;
const find=(n,k,v)=>n.attrs[k]===v?n:n.children.map(c=>find(c,k,v)).find(Boolean);
mkdirSync(output,{recursive:true});
// Fixed RNG only affects idle phase; rig geometry and facial values stay unchanged.
Math.random=()=>.25;
for(const id of ['barista','beard','hawaii']){
 for(const emotion of EMOTIONS.map(e=>e.id)){
  const host=new SvgNode('svg'),actors=createActors(host);
  actors.setEmotion(id,emotion,50);actors.tick(.1);
  const actor=find(host,'data-actor',id),motion=actor.children[0],defs=host.children[0];
  const head=motion.children.at(-1);delete head.attrs.transform;
  const save=(name,nodes)=>writeFileSync(resolve(output,`${id}-${name}.svg`),`<svg xmlns="http://www.w3.org/2000/svg" width="440" height="820" viewBox="-200 -130 440 820">${xml(defs)}${nodes.map(xml).join('')}</svg>\n`);
  save(`head-${emotion}`,[head]);
  actors.blink(id);actors.tick(.1176);save(`head-${emotion}-blink`,[head]);
  if(emotion==='neutral'){
   save('body',[id==='barista'?motion.children[0]:motion.children[1]]);
   if(id!=='barista'){
    const legs=motion.children[0];
    save('hips',[legs.children[0]]);
    legs.children.slice(1).forEach((leg,i)=>{delete leg.attrs.transform;delete leg.children[0]?.attrs.transform;save(`leg${i}`,[leg]);});
   }
  }
 }
}
const html=readFileSync(resolve(source,'index.html'),'utf8');
const outlines=[...html.matchAll(/class="outline" d="([^"]+)"/g)];
for(const [i,match] of outlines.entries())writeFileSync(resolve(output,`outline${i}.svg`),`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900"><path d="${match[1]}" fill="none" stroke="white" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/></svg>`);
copyFileSync(resolve(source,'assets/cafe-animation-room.png'),resolve(output,'room.png'));
const paths=['actors.mjs','assets/cafe-animation-room.png','index.html','style.css'];
const sources=Object.fromEntries(paths.map(p=>[p,createHash('sha256').update(readFileSync(resolve(source,p))).digest('hex')]));
writeFileSync(resolve(output,'SOURCE.json'),JSON.stringify({approval:'VISUAL-002/v9',site:'appgprj_6ae1b4d1e3bc8191b569fb298107c732',commit:'bda169a08fe6287c5c9ce9a8b57dfa8412e7a937',scope:'Original room and temporary rigs. Native pose implementation is a new work build, not final animation approval.',sources},null,2)+'\n');
console.log('Exported original room and 3 layered SVG rigs / 8 emotions / blink variants.');
