import {createGame,recipes} from './game.mjs';
import {UPGRADES} from './shell-state.mjs';
const KEYS=['barista.save.0','barista.save.1'];
const moods=['neutral','happy','delighted','impatient','angry','disappointed','surprised'];
const nonnegative=n=>Number.isFinite(n)&&n>=0;
function valid(g){
 if(!g||!nonnegative(g.clock)||!Number.isSafeInteger(g.nextId)||g.nextId<1||!Number.isSafeInteger(g.money)||g.money<0)return false;
 if(g.finishRemaining!==undefined&&g.finishRemaining!==null&&(!nonnegative(g.finishRemaining)||g.finishRemaining>1.5))return false;
 if(g.meta!==undefined&&(!g.meta||typeof g.meta.sound!=='boolean'||!Number.isSafeInteger(g.meta.firstDay)||!g.meta.upgrades||!Object.entries(UPGRADES).every(([id,v])=>Number.isInteger(g.meta.upgrades[id])&&g.meta.upgrades[id]>=0&&g.meta.upgrades[id]<=v.max)))return false;
 const a=g.active;
 if(!a||!Object.hasOwn(recipes,a.recipe)||!Array.isArray(a.taps)||a.taps.length!==3||!a.taps.every(n=>Number.isSafeInteger(n)&&n>=0)||![0,1,2].includes(a.stage)||!nonnegative(a.quality)||a.quality>1)return false;
 if(!Array.isArray(g.cups)||g.cups.length>4||new Set(g.cups.map(c=>c?.id)).size!==g.cups.length||new Set(g.cups.map(c=>c?.slot)).size!==g.cups.length)return false;
 if(!g.cups.every(c=>c&&Number.isSafeInteger(c.id)&&c.id>0&&c.id<g.nextId&&Object.hasOwn(recipes,c.recipe)&&[0,1,2,3].includes(c.slot)&&nonnegative(c.age)&&nonnegative(c.quality)&&c.quality<=1&&(c.initialTemperature===undefined||(c.initialTemperature>=22&&c.initialTemperature<=95))))return false;
 const initial=createGame().customers;
 return Array.isArray(g.customers)&&g.customers.length===initial.length&&g.customers.every((c,i)=>{
  const original=initial[i];
  return c&&c.id===original.id&&c.name===original.name&&c.recipe===original.recipe&&c.max===original.max&&nonnegative(c.patience)&&c.patience<=c.max&&moods.includes(c.mood)&&typeof c.lastReaction==='string'&&['served','collected','departed','unpaid'].every(k=>c[k]===undefined||typeof c[k]==='boolean')&&(!c.served||(nonnegative(c.paymentDeadline)&&[80,100,120].includes(c.payment)&&['happy','ordinary','late','bitter','cold','wrong','wrong-cold'].includes(c.kind)))&&(c.returnAt===undefined||nonnegative(c.returnAt))&&(!c.collected||c.served);
 });
}
function readSlots(storage){return KEYS.map(key=>{try{const r=JSON.parse(storage.getItem(key));return r?.schema_version===1&&Number.isSafeInteger(r.sequence)&&r.sequence>0&&valid(r.game)?r:null;}catch{return null;}}).filter(Boolean).sort((a,b)=>b.sequence-a.sequence);}
export function loadGame(storage){try{return {game:readSlots(storage)[0]?.game??null};}catch{return {game:null};}}
export function saveGame(storage,game){
 if(!valid(game))return {ok:false};
 try{const sequence=(readSlots(storage)[0]?.sequence??0)+1;
  // Each localStorage setItem is atomic. Keep the other complete snapshot on failure.
  storage.setItem(KEYS[(sequence-1)%2],JSON.stringify({schema_version:1,sequence,game}));return {ok:true};
 }catch{return {ok:false};}
}
