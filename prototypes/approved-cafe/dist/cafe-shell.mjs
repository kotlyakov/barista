import {UPGRADES,PRICES,ensureMeta,workDay,createShell,introFrame,skipIntro,openMenu,openProgress,continueGame} from './shell-state.mjs';
export function mountCafeShell(api,audio){
 const $=s=>document.querySelector(s),scene=$('#scene'),state=createShell();
 const meta=ensureMeta(api.game());audio.setEnabled(meta.sound);
 scene.insertAdjacentHTML('beforeend',`<header class="cafe-hud"><div class="cafe-title">Путь баристы</div><div class="hud-stats"><span id="work-day"></span><span id="hud-wallet"></span><button id="menu-open" aria-label="Открыть меню" aria-expanded="false"><i></i><i></i><i></i></button></div></header>
 <div id="cafe-menu" class="cafe-menu" hidden><section role="dialog" aria-modal="true" aria-label="Меню паузы"><h1>Пауза</h1><button id="menu-continue">Продолжить</button><button id="sound-switch" aria-pressed="true"></button><button id="progress-open">Прогресс</button><p id="save-state" role="status">Прогресс сохранён</p></section></div>
 <section id="cafe-progress" class="cafe-progress" aria-label="Прогресс и улучшения" hidden><h1>Твоя кофейня</h1><button id="progress-back">Назад в меню</button><div id="powerups"></div><div id="upgrade-detail" hidden></div><p id="upgrade-result" role="status"></p></section>
 <button id="cafe-intro" class="cafe-intro" aria-label="Пропустить вступление"><span class="intro-room"></span><svg class="intro-drawing" viewBox="0 0 1600 900" aria-hidden="true"><path id="door-light" d="M1270 24 H1480 V360 L1560 860 L1170 650 Z" fill="#eec88b"/><path id="intro-door" d="M1270 24 H1480 V360 H1270Z" fill="#101721" stroke="#58616b" stroke-width="4"/><g id="intro-walker"><path id="intro-leg-left" d="M-50 330 L-53 480 L-65 540" fill="none" stroke="#171b24" stroke-width="43" stroke-linecap="round"/><path id="intro-leg-right" d="M25 330 L29 480 L43 540" fill="none" stroke="#171b24" stroke-width="43" stroke-linecap="round"/></g><image href="assets/cafe-animation-room.png" width="1600" height="900" preserveAspectRatio="none" clip-path="url(#counter-front-clip)" opacity=".065"/><path id="switch-hand" d="M250 430 Q220 310 175 240" fill="none" stroke="#b97c57" stroke-width="19" stroke-linecap="round" opacity="0"/><circle id="light-switch" cx="172" cy="236" r="7" fill="#efd99e"/></svg><span class="intro-caption">Путь баристы<small>Коснись экрана, чтобы пропустить</small></span></button>`);
 const intro=$('#cafe-intro'),walker=$('#intro-walker'),barista=$('[data-actor="barista"]')?.cloneNode(true);
 if(barista){barista.removeAttribute('transform');barista.removeAttribute('data-actor');walker.append(barista);}
 let started=null,hiddenAt=null,selectedUpgrade=null;
 function hud(){const g=api.game();$('#work-day').textContent='День '+workDay(g);$('#hud-wallet').textContent=g.money.toLocaleString('ru-RU')+' ₽';$('#sound-switch').textContent=ensureMeta(g).sound?'Звук включён':'Звук выключен';$('#sound-switch').setAttribute('aria-pressed',String(ensureMeta(g).sound));}
 function apply(){
  const locked=state.paused||document.hidden;api.pause(locked);audio.setPaused(locked);
  scene.dataset.view=state.view;$('#cafe-menu').hidden=state.view!=='menu';$('#cafe-progress').hidden=state.view!=='progress';intro.hidden=state.view!=='intro';
  $('#menu-open').setAttribute('aria-expanded',String(state.view==='menu'));hud();
 }
 function save(){const ok=api.save();$('#save-state').textContent=ok?'Прогресс сохранён':'Не удалось сохранить — не закрывай игру';return ok;}
 function finishIntro(){if(state.view!=='intro')return;skipIntro(state);apply();void audio.unlock();}
 intro.onclick=e=>{e.stopPropagation();finishIntro();};
 $('#menu-open').onclick=()=>{if(state.view==='intro')return;openMenu(state);api.cancelDrag();save();apply();$('#menu-continue').focus();};
 $('#menu-continue').onclick=()=>{continueGame(state);apply();void audio.unlock();};
 $('#sound-switch').onclick=()=>{const m=ensureMeta(api.game()),old=m.sound;m.sound=!m.sound;if(!save())m.sound=old;audio.setEnabled(m.sound);hud();};
 function powers(){
  const g=api.game();$('#powerups').innerHTML=Object.entries(UPGRADES).map(([id,u])=>{const level=ensureMeta(g).upgrades[id];return `<button class="powerup-pin" data-upgrade="${id}" style="left:${u.anchor[0]}%;top:${u.anchor[1]}%"><span>${u.name}</span><small>${'●'.repeat(level)}${'○'.repeat(u.max-level)}</small></button>`;}).join('');
 }
 function detail(id){
  selectedUpgrade=id;const g=api.game(),u=UPGRADES[id],level=ensureMeta(g).upgrades[id],el=$('#upgrade-detail');el.hidden=false;
  el.innerHTML=`<button id="upgrade-close" aria-label="Закрыть описание">×</button><h2>${u.name}</h2><p>${u.description}</p><small>Уровень ${level} из ${u.max}</small><button id="upgrade-buy" ${level>=u.max?'disabled':''}>${level>=u.max?'Максимальный уровень':PRICES[level]+' монет · улучшить'}</button>`;
  $('#upgrade-close').onclick=()=>{el.hidden=true;selectedUpgrade=null;};
  $('#upgrade-buy').onclick=()=>{const result=api.purchase(id,level);$('#upgrade-result').textContent=result.text;hud();powers();detail(id);if(result.ok)audio.coins();};
 }
 $('#progress-open').onclick=()=>{openProgress(state);apply();powers();$('#upgrade-detail').hidden=true;$('#upgrade-result').textContent='';};
 $('#progress-back').onclick=()=>{openMenu(state);apply();};
 $('#powerups').onclick=e=>{const b=e.target.closest('[data-upgrade]');if(b)detail(b.dataset.upgrade);};
 document.addEventListener('keydown',e=>{if(e.key!=='Escape')return;if(state.view==='intro')finishIntro();else if(state.view==='progress'){openMenu(state);apply();}else if(state.view==='menu'){continueGame(state);apply();}else $('#menu-open').click();});
 document.addEventListener('pointerdown',()=>{void audio.unlock();},{passive:true});
 document.addEventListener('visibilitychange',()=>{if(document.hidden){hiddenAt=performance.now();save();}else{if(started!==null&&hiddenAt!==null)started+=performance.now()-hiddenAt;hiddenAt=null;}apply();});
 window.addEventListener('pagehide',save);
 function frame(now){
  if(state.view==='intro'&&!document.hidden){
   if(started===null)started=now;const elapsed=now-started,f=introFrame(elapsed);
   intro.style.setProperty('--room-light',String(f.light));$('#intro-door').style.transform=`scaleX(${1-.88*f.door})`;$('#door-light').style.opacity=String(f.door*.2*(1-f.light));
   walker.setAttribute('transform',`translate(${f.x} ${f.y+f.walk*.15}) scale(${f.scale})`);walker.style.opacity=String(1-f.light);$('#intro-leg-left').setAttribute('transform',`rotate(${f.walk*3} -50 330)`);$('#intro-leg-right').setAttribute('transform',`rotate(${-f.walk*3} 25 330)`);$('#switch-hand').style.opacity=elapsed>2480?String(1-f.light):'0';
   if(f.done)finishIntro();
  }
  hud();requestAnimationFrame(frame);
 }
 apply();requestAnimationFrame(frame);
}
