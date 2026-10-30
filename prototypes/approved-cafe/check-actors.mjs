import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createActors} from './dist/actors.mjs';
// Minimal SVG DOM for exercising animation transforms without a browser dependency.
class SvgNode{
 constructor(tag){this.tag=tag;this.attrs={};this.children=[];}
 setAttribute(k,v){this.attrs[k]=String(v);}
 getAttribute(k){return this.attrs[k]??null;}
 appendChild(n){n.remove();this.children.push(n);n.parent=this;return n;}
 insertBefore(n,b){n.remove();this.children.splice(this.children.indexOf(b),0,n);n.parent=this;}
 remove(){if(this.parent){this.parent.children=this.parent.children.filter(n=>n!==this);this.parent=null;}}
}
globalThis.document={createElementNS:(_,tag)=>new SvgNode(tag)};
const host=new SvgNode('svg'),actors=createActors(host);
const find=(attr,value,node=host)=>node.attrs[attr]===value?node:node.children.map(n=>find(attr,value,n)).find(Boolean);
actors.enter();const samples=[];
for(let t=0;t<85;t++){actors.tick(.1);const p=actors.pose('beard');samples.push({y:p.y,leg:find('data-leg','0',find('data-actor','beard')).attrs.transform,knee:find('data-knee','true',find('data-actor','hawaii')).attrs.transform});}
assert.equal(actors.isArrived('beard'),true);assert.equal(actors.isArrived('hawaii'),true);
assert.ok(new Set(samples.slice(10,40).map(s=>s.leg)).size>20,'walking articulates whole leg');
assert.ok(new Set(samples.slice(10,40).map(s=>s.knee)).size>10,'Hawaiian knee bends independently');
assert.ok(samples.every((s,i)=>!i||s.y>=samples[i-1].y-.001),'arrival has no alternating vertical head jumps');
const mouth=find('data-mouth','beard'),neutral=mouth.attrs.d;actors.setEmotion('beard','delighted',1200);actors.tick(.2);const midway=mouth.attrs.d;actors.tick(.5);actors.tick(.5);const smile=mouth.attrs.d;
assert.notEqual(midway,neutral);assert.notEqual(midway,smile);assert.notEqual(smile,neutral);
assert.equal(find('data-teeth','beard').attrs.opacity,'1');assert.equal(find('data-teeth','beard').attrs['clip-path'],'url(#mouth-clip-beard)');assert.equal(find('id','mouth-clip-beard').children[0].attrs.d,mouth.attrs.d,'teeth are clipped inside the animated mouth');assert.equal(mouth.attrs.stroke,'#dba27d');
actors.setEmotion('beard','angry',800);actors.tick(.4);actors.tick(.4);assert.notEqual(mouth.attrs.d,smile);
actors.setPaused(true);const pose={...actors.pose('beard')},frozen=mouth.attrs.d;actors.tick(.5);assert.deepEqual(actors.pose('beard'),pose);assert.equal(mouth.attrs.d,frozen);actors.setPaused(false);
actors.leave('beard');for(let i=0;i<55;i++)actors.tick(.1);assert.equal(actors.isPresent('beard'),false);
assert.match(readFileSync('dist/index.html','utf8'),/M0 681 L332 677 L698 649 L1218 617 L1220 900 H0 Z/,'counter is composited in front of characters');
console.log('PASS: alternating hips/knees, smooth entrance without head hops, gradual contrasting expressions, pause, departure, foreground counter.');
