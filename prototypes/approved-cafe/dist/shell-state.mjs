export const UPGRADES={
 grind:{name:'Жернова',max:3,description:'На 1 тап меньше при помоле',anchor:[12,49]},
 brew:{name:'Кофемашина',max:3,description:'На 1 тап меньше при варке',anchor:[34,34]},
 milk:{name:'Капучинатор',max:3,description:'На 1 тап меньше для молока',anchor:[53,24]},
 tuning:{name:'Точная настройка',max:3,description:'Ошибки портят вкус на 10% меньше',anchor:[20,85]},
 grace:{name:'Защита от ошибки',max:2,description:'Ещё 1 лишний тап без порчи',anchor:[45,80]},
 ads:{name:'Реклама кофейни',max:3,description:'Гости возвращаются на 10% быстрее',anchor:[83,45]}
};
export const PRICES=[400,800,1400];
export function ensureMeta(g){
 if(!g.meta)g.meta={sound:true,firstDay:dayStamp(Date.now()),upgrades:Object.fromEntries(Object.keys(UPGRADES).map(k=>[k,0]))};
 return g.meta;
}
function dayStamp(now){const d=new Date(now);if(d.getHours()<8)d.setDate(d.getDate()-1);return Date.UTC(d.getFullYear(),d.getMonth(),d.getDate());}
export function workDay(g,now=Date.now()){return Math.max(1,1+Math.floor((dayStamp(now)-ensureMeta(g).firstDay)/86400000));}
export function createShell(){return {view:'intro',paused:true};}
export function skipIntro(s){s.view='play';s.paused=false;}
export function openMenu(s){if(s.view!=='intro'){s.view='menu';s.paused=true;}}
export function openProgress(s){if(s.view==='menu'){s.view='progress';s.paused=true;}}
export function continueGame(s){if(s.view==='menu'){s.view='play';s.paused=false;}}
export function introFrame(ms,skip=false){
 const t=skip?1:Math.max(0,Math.min(1,ms/3000)),u=Math.max(0,Math.min(1,(t-.13)/.7)),p=u*u*(3-2*u);
 return {done:t>=1,door:Math.min(1,t/.2),x:1470-1160*p,y:180+90*p,scale:.28+.72*p,light:Math.max(0,Math.min(1,(t-.87)/.13)),walk:u>0&&u<1?Math.sin(ms/75)*5:0};
}
export function buyUpgrade(g,id,expectedLevel){
 const meta=ensureMeta(g),item=UPGRADES[id],level=meta.upgrades[id];
 if(!item||!Number.isInteger(expectedLevel)||level!==expectedLevel||level>=item.max)return {ok:false,text:'Это улучшение уже куплено'};
 if(g.active.taps.some(Boolean)||g.cups.length||g.customers.some(c=>c.served&&!c.collected&&!c.departed))return {ok:false,text:'Сначала закончи заказ и освободи стойку'};
 const price=PRICES[level];if(g.money<price)return {ok:false,text:'Пока не хватает монет'};
 g.money-=price;meta.upgrades[id]++;return {ok:true,text:item.name+' · уровень '+(level+1)};
}
export function purchaseSaved(g,id,expectedLevel,persist){
 const meta=ensureMeta(g),money=g.money,level=meta.upgrades[id],result=buyUpgrade(g,id,expectedLevel);
 if(result.ok&&!persist()){g.money=money;meta.upgrades[id]=level;return {ok:false,text:'Не удалось сохранить. Покупка отменена'};}
 return result;
}
