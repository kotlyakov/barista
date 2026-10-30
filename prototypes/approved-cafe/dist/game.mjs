export const recipes={cappuccino:'Капучино',espresso:'Эспрессо',latte:'Латте'};
export const TAPS=12, PAYMENT_SECONDS=12;
export function createGame(){return {clock:0,nextId:1,money:0,cups:[],active:{recipe:'cappuccino',taps:[0,0,0],stage:0,quality:1},customers:[{id:'beard',name:'Бородач',recipe:'cappuccino',patience:150,max:150,mood:'neutral',lastReaction:''},{id:'hawaii',name:'Гаваец',recipe:'espresso',patience:190,max:190,mood:'neutral',lastReaction:''}]};}
export function steps(g){return g.active.recipe==='espresso'?2:3;}
export function targetTaps(g,s){const level=g.meta?.upgrades?.[['grind','brew','milk'][s]]??0;return Math.max(1,TAPS-level);}
export function stageDamaged(g,s){return g.active.taps[s]>targetTaps(g,s)+(g.meta?.upgrades?.grace??0);}
export function ready(g){return g.active.taps.slice(0,steps(g)).every((n,s)=>n>=targetTaps(g,s));}
export function tap(g,s){const a=g.active;if(s>=steps(g))return {ok:false,text:'Для эспрессо молоко не нужно'};if(s<a.stage)return {ok:false,text:'Этот этап уже закончен'};if(s>0&&a.taps[s-1]<targetTaps(g,s-1))return {ok:false,text:'Сначала закончи предыдущий этап'};a.stage=s;a.taps[s]++;if(stageDamaged(g,s))a.quality=Math.max(0,a.quality-.16*Math.pow(.9,g.meta?.upgrades?.tuning??0));return {ok:true,text:stageDamaged(g,s)?'Перетап':a.taps[s]===targetTaps(g,s)?'Следующий прибор':'Продолжай'};}
export function finish(g){if(!ready(g)||g.cups.length>=4)return null;const a=g.active,c={id:g.nextId++,recipe:a.recipe,quality:a.quality,age:0,slot:[0,1,2,3].find(s=>!g.cups.some(c=>c.slot===s))};g.cups.push(c);g.active={recipe:a.recipe,taps:[0,0,0],stage:0,quality:1};return c;}
export function temperature(c){return Math.max(22,Math.min(95,(c.initialTemperature??88)-c.age*.35));}
export function setTemperature(c,degrees){c.initialTemperature=Math.max(22,Math.min(95,degrees));c.age=0;}
export function steamLevel(c){return Math.max(0,Math.min(1,(temperature(c)-50)/38));}
export function advance(g,seconds){
 g.clock+=seconds;g.cups.forEach(c=>c.age+=seconds);
 for(const c of g.customers){
  if(c.departed){
   c.returnAt??=g.clock+9*Math.pow(.9,g.meta?.upgrades?.ads??0);
   if(g.clock>=c.returnAt){const {id,name,recipe,max,mood,lastReaction}=c;for(const key of Object.keys(c))delete c[key];Object.assign(c,{id,name,recipe,max,mood,lastReaction,patience:max,departed:false});}
   continue;
  }
  if(!c.served){c.patience=Math.max(0,c.patience-seconds);if(c.patience/c.max<=.55)c.mood=c.patience/c.max>.2?'impatient':'angry';}
  else if(!c.collected&&g.clock>=c.paymentDeadline){c.departed=true;c.unpaid=true;}
 }
}
export function serve(g,cupId,customerId){const cup=g.cups.find(c=>c.id===cupId),c=g.customers.find(c=>c.id===customerId);if(!cup||!c||c.served||c.departed)return {ok:false};const wrong=cup.recipe!==c.recipe,cold=temperature(cup)<50,bitter=cup.quality<.8,late=c.patience<=0;const kind=wrong?(cold?'wrong-cold':'wrong'):cold?'cold':bitter?'bitter':late?'late':cup.quality<1?'ordinary':'happy';const texts={wrong:'Не мой!','wrong-cold':'Фу, холодный!',cold:'Остыл…',bitter:'Горчит!',late:'Наконец-то…',ordinary:'Обычно.',happy:'Кайф!'};g.cups=g.cups.filter(x=>x.id!==cupId);Object.assign(c,{served:true,servedRecipe:cup.recipe,kind,reaction:texts[kind],lastReaction:texts[kind],mood:kind==='happy'?'delighted':kind==='ordinary'?'neutral':kind==='bitter'?'angry':'disappointed',payment:kind==='happy'?120:kind==='ordinary'?100:80,collected:false,paymentDeadline:g.clock+PAYMENT_SECONDS});return {ok:true,kind,text:c.reaction};}
export function collectPayment(g,customerId){const c=g.customers.find(c=>c.id===customerId);if(!c?.served||c.collected||c.departed||g.clock>=c.paymentDeadline)return {ok:false,amount:0};c.collected=true;g.money+=c.payment;return {ok:true,amount:c.payment};}
