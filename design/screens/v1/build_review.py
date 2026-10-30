#!/usr/bin/env python3
"""Reproducible owner-review material, not production game UI. Pillow only."""
from pathlib import Path
import base64, html, json, math, random, struct, wave
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'design/screens/v1'
ANIM=ROOT/'design/animations/v1'
AUDIO=ROOT/'audio/candidates/v1'
BG='#171e21'; PANEL='#242e30'; MUTED='#acb8b4'; WHITE='#f5ead8'; GOLD='#e7b66d'; GREEN='#8bc5a2'; RED='#ee9b88'
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
SCREENS={}; LINKS={}; measures=[]

class Canvas:
 def __init__(self):
  self.im=Image.new('RGB',(1600,900),BG);self.d=ImageDraw.Draw(self.im);self.svg=[]
 def rect(self,x,y,w,h,fill=PANEL,r=20,stroke=None):
  self.d.rounded_rectangle((x,y,x+w,y+h),r,fill,outline=stroke,width=2)
  self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="2"' if stroke else '')+'/>')
 def text(self,x,y,s,size=26,fill=WHITE,bold=False):
  f=ImageFont.truetype(BOLD if bold else FONT,size)
  w=self.d.textlength(s,font=f);assert x+w<=1545,(s,x,w)
  self.d.text((x,y),s,font=f,fill=fill,anchor='lt')
  self.svg.append(f'<text x="{x}" y="{y+size*.82}" fill="{fill}" font-family="DejaVu Sans,sans-serif" font-size="{size}"'+(' font-weight="700"' if bold else '')+'>'+html.escape(s)+'</text>')
  measures.append((s,round(w,1)))
 def line(self,x,y,w,progress,color=GREEN):
  self.rect(x,y,w,12,'#101719',6)
  if progress:self.rect(x,y,max(12,int(w*progress)),12,color,6)
 def button(self,x,y,w,label,target=None,secondary=False):
  self.rect(x,y,w,64,PANEL if secondary else GOLD,16, '#546361' if secondary else None)
  f=ImageFont.truetype(BOLD,24);tw=self.d.textlength(label,font=f);assert tw<w-32,(label,w)
  self.text(x+(w-tw)/2,y+20,label,24,WHITE if secondary else BG,True)
  if target:LINKS.setdefault(self.key,[]).append(dict(x=x,y=y,w=w,h=64,target=target,label=label))
 def header(self,k,title,sub,tag='ПУТЬ БАРИСТЫ'):
  self.key=k;self.text(70,46,tag,21,GOLD,True);self.text(70,100,title,49,WHITE,True);self.text(72,170,sub,24,MUTED)
 def save(self):
  SCREENS[self.key]=self.im.copy()
  (OUT/f'{self.key}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900"><rect width="1600" height="900" fill="'+BG+'"/>'+''.join(self.svg)+'</svg>')
  self.im.save(OUT/f'{self.key}.png')

def screens():
 c=Canvas();c.header('start','Хороший кофе начинается с тебя','Твоя кофейня. Твой ритм. Каждый гость запоминает заботу.')
 c.rect(70,250,890,370);c.text(115,297,'Новая смена',36,WHITE,True);c.text(115,365,'8 минут за стойкой',29);c.text(115,418,'Сегодня: спокойное утро',27,GREEN);c.text(115,470,'Гости готовы подождать чуть дольше.',25,MUTED)
 c.button(115,530,360,'Открыть кофейню','shop');c.rect(1000,250,530,370);c.text(1040,297,'Сначала попробуем?',32,WHITE,True);c.text(1040,370,'Один учебный капучино.',25);c.text(1040,415,'Без таймера и потери монет.',23,MUTED);c.button(1040,530,440,'Научиться готовить','learn-0',True)
 c.button(70,720,260,'Настройки','settings',True);c.button(360,720,280,'Тренировка','learn-0',True);c.text(1050,746,'Монеты  ·  1 240',30,GOLD,True);c.save()
 c=Canvas();c.header('shop','Перед открытием','Постоянные улучшения остаются с тобой после смены.');c.text(1190,62,'1 240 монет',28,GOLD,True)
 cards=[('Жернова','Уровень 1 → 2','Помол: 11 → 10 тапов','800 монет','shop-bought'),('Кофемашина','Уровень 0 → 1','Варка: 16 → 15 тапов','400 монет',None),('Капучинатор','Уровень 0 → 1','Молоко: на 1 тап меньше','400 монет',None),('Точная настройка','Уровень 0 → 1','Потеря качества: −10%','400 монет',None),('Защита от ошибки','Уровень 0 → 1','1 лишний тап без порчи','400 монет',None),('Реклама кофейни','Уровень 3 из 3','Гости приходят чаще','Максимум',None)]
 for i,(name,level,effect,price,target) in enumerate(cards):
  x=70+(i%3)*495;y=230+(i//3)*235;c.rect(x,y,470,210);c.text(x+26,y+22,name,28,WHITE,True);c.text(x+26,y+65,level,20,MUTED);c.text(x+26,y+103,effect,23,GREEN);c.button(x+26,y+140,418,price,target,True)
 c.text(72,742,'Можно начать смену без покупок.',24,MUTED);c.button(1120,718,410,'Дальше: усиление','perks');c.save()
 c=Canvas();c.header('shop-bought','Покупка готова','Пример подтверждения покупки; повторный тап не списывает монеты.');c.rect(240,255,1120,330);c.text(310,310,'Новые жернова',40,WHITE,True);c.text(310,383,'Уровень 2 · для помола теперь нужно 10 тапов.',29,GREEN);c.text(310,448,'800 монет списано · осталось 440 монет',26,MUTED);c.button(310,505,440,'Вернуться к улучшениям','shop');c.button(1120,718,410,'Дальше: усиление','perks');c.save()
 c=Canvas();c.header('perks','Маленькое преимущество','Выбери одно бесплатное усиление на эту смену.');c.rect(70,221,1460,84);c.text(103,249,'Спокойное утро · терпение гостей +20%',28,GREEN)
 for i,(name,a,b,target) in enumerate([('Лёгкий помол','На 2 тапа меньше','при каждом помоле','perk-selected'),('Твёрдая рука','1 безопасный лишний тап','на каждом этапе',None),('Есть минутка','Терпение гостей +25%','в дополнение к условию дня',None)]):
  x=70+i*495;c.rect(x,340,470,310);c.text(x+30,380,name,31,WHITE,True);c.text(x+30,450,a,24);c.text(x+30,493,b,21,MUTED);c.button(x+30,550,410,'Выбрать',target,True)
 c.text(74,751,'Действует только до итога этой смены.',25,MUTED);c.button(1140,718,390,'Сначала выбери бонус',None,True);c.save()
 c=Canvas();c.header('perk-selected','Всё готово к открытию','Твой выбор сохранён. Он не меняется при перезапуске.');c.rect(70,260,1460,330);c.text(120,310,'Лёгкий помол',43,WHITE,True);c.text(120,390,'На 2 тапа меньше при каждом помоле.',31,GREEN);c.text(120,455,'Условие дня: спокойное утро.',26,MUTED);c.text(120,508,'Постоянные покупки и усиление работают вместе.',25,MUTED);c.button(1090,718,440,'Начать смену','learn-0');c.save()
 for passed in [True,False]:
  k='summary' if passed else 'summary-fail';c=Canvas();c.header(k,'Кофейня закрыта. До завтра!','Заработанное, оборудование и отношения с гостями сохранены.')
  c.rect(70,245,850,405);c.text(110,284,'Твоя смена',34,WHITE,True)
  for i,(a,b) in enumerate([('Выдано напитков','12'),('Хороших и идеальных','10 из 12 · 83%' if passed else '8 из 12 · 67%'),('Собрано за заказы','1 040 монет'),('Из них чаевые','80 монет')]):
   c.text(110,356+i*63,a,25,MUTED);c.text(590,356+i*63,b,25,WHITE,True)
  c.rect(950,245,580,405);c.text(990,284,'Цель выполнена' if passed else 'Есть куда расти',33,GREEN if passed else GOLD,True);c.text(990,358,'10 выдач и 80% хороших',25);c.text(990,413,'Награда: 200 монет' if passed else 'Нужно 80% хороших заказов.',25,GOLD);c.text(990,468,'Деньги за заказы уже в кошельке.' if passed else 'Заказы оплачены. Награды нет.',21,MUTED);c.button(990,552,500,'Забрать 200 монет' if passed else 'Завершить смену','summary-claimed');c.button(70,718,310,'Тренировка','learn-0',True);c.text(920,744,'Следующая смена после 08:00',27,MUTED);c.save()
 c=Canvas();c.header('summary-claimed','Всё сохранено','Итог смены сохранён. Можно спокойно закрыть игру.');c.rect(70,260,1460,330);c.text(120,316,'До следующей смены',41,WHITE,True);c.text(120,396,'Кофейня снова откроется после 08:00.',30,MUTED);c.text(120,465,'Тренировка доступна сейчас и не меняет твой прогресс.',28,GREEN);c.button(70,718,360,'Потренироваться','learn-0');c.button(1110,718,420,'На главный экран','start',True);c.save()
 c=Canvas();c.header('settings','Сделаем паузу','Смена и заказ ждут тебя. Таймер остановлен.')
 c.rect(70,230,880,440)
 for i,(label,p) in enumerate([('Общая громкость',.75),('Музыка',.45),('Эффекты',.8)]):
  y=272+i*100;c.text(110,y,label,27);c.line(480,y+14,390,p,GOLD)
 c.text(110,572,'Вибрация',27);c.rect(750,565,120,45,GREEN,22);c.rect(818,570,37,35,WHITE,17)
 c.rect(980,230,550,440);c.text(1020,276,'В своём темпе',32,WHITE,True);c.text(1020,344,'Обучение можно повторить.',24,MUTED);c.text(1020,388,'Без изменений основной игры.',22,MUTED);c.button(1020,472,470,'Повторить обучение','learn-0',True);c.button(1020,559,470,'Главный экран','start',True);c.button(70,718,440,'Продолжить','learn-0');c.save()
 steps=[('Помол','Тапай по кофемолке до заполнения полосы.','Помол'),('Остановись','Полоса готова. Лишние тапы дадут горечь.','Готово'),('Варка','Тапни по кофемашине — начнётся варка.','Варка'),('Молоко','Заполни полосу капучинатора и остановись.','Молоко'),('Отдай напиток','Перетащи стакан к гостю. Мимо — вернётся.','Стакан → гость'),('Собери оплату','Тапни по монетам. Только теперь они твои.','Монеты')]
 for i,(title,sub,label) in enumerate(steps):
  c=Canvas();c.header(f'learn-{i}',title,sub,f'ПЕРВЫЙ КАПУЧИНО  ·  {i+1} / 6');c.rect(70,250,1460,325);c.text(118,290,'Обучение',24,GOLD,True);c.text(118,348,'Отдельный учебный заказ',38,WHITE,True);c.text(118,410,'Основной прогресс остаётся прежним.',26,MUTED);c.rect(1010,286,470,230,'#31403d',25,GREEN);c.text(1050,370,label,29,GREEN,True);c.line(118,497,780,(i+1)/6)
  c.text(72,625,'Здесь будет утверждённая стойка 09 с подсветкой нужной зоны.',24,MUTED);c.button(70,718,340,'Пропустить','start',True);c.button(1120,718,410,'Готово' if i==5 else 'Далее','start' if i==5 else f'learn-{i+1}');c.save()

def animation():
 frames=[]
 for i in range(120):
  t=i/20;c=Canvas();c.header('motion','От готовности до оплаты','Демонстрация сигналов интерфейса · графика стойки остаётся прежней.')
  c.rect(120,260,1360,370)
  if t<1.5:
   c.text(180,310,'Готовность',36,WHITE,True);c.line(180,410,1200,min(1,t/1),GREEN);c.text(180,500,'Готово — переходи к следующему прибору' if t>=1 else 'Полоса заполняется без чисел',28,GREEN)
  elif t<2.7:
   c.text(180,310,'Лишний тап',36,WHITE,True);c.line(180,410,1200,1,RED);c.text(180,500,'Горчит · цвет и знак предупреждают вместе',28,RED)
  elif t<4.4:
   c.text(180,310,'Отпущено мимо — стакан возвращается',34,WHITE,True);u=min(1,(t-2.7)/.7);x=1000-740*(1-(1-u)**3);c.rect(x,420,70,95,WHITE,12);c.text(180,555,'Приборы после взятия стакана остаются заблокированы.',24,MUTED)
  else:
   c.text(180,310,'Выдача → оплата → сбор',36,WHITE,True);c.rect(1060,390,300,120,GOLD);c.text(1100,425,'88 монет',30,BG,True);c.text(180,470,'80 за кофе + 8 чаевых',29,GREEN);c.text(180,550,'После сбора: +88 в кошелёк один раз',27,MUTED)
  frames.append(c.im.resize((960,540)))
 frames[0].save(ANIM/'feedback-v1.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=True)

def sounds():
 sr=24000; rng=random.Random(301026)
 def write(name,duration,fn):
  n=int(sr*duration);samples=[]
  for i in range(n):
   t=i/sr;fade=min(1,t/.01,(duration-t)/.03);v=fn(t)*max(0,fade);samples.append(max(-32767,min(32767,round(v*32767))))
  with wave.open(str(AUDIO/(name+'.wav')),'wb') as w:
   w.setparams((1,2,sr,n,'NONE','not compressed'));w.writeframes(struct.pack('<'+'h'*n,*samples))
 def tone(t,f):return math.sin(math.tau*f*t)
 mapping=[('tap','Тап',.07,lambda t:.12*tone(t,420)*math.exp(-t*60)),('grind','Помол',1.2,lambda t:.065*(rng.random()*2-1)+.04*tone(t,110)*(1+.2*tone(t,7))),('brew','Пролив',1.4,lambda t:.07*(rng.random()*2-1)*(.6+.4*tone(t,31))),('steam','Пар',1.2,lambda t:.055*(rng.random()*2-1)*(1+.2*tone(t,5))),('ready','Готовность',.4,lambda t:.13*tone(t,660 if t<.16 else 880)*math.exp(-t*3)),('damage','Перетап',.28,lambda t:.09*tone(t,300-400*t)*math.exp(-t*7)),('serve','Выдача',.22,lambda t:.1*tone(t,500)*math.exp(-t*20)+.035*(rng.random()*2-1)*math.exp(-t*30)),('coins','Монеты',.48,lambda t:.10*(tone(t,1319)+.35*tone(t,1976))*math.exp(-t*9)),('purchase','Покупка',.5,lambda t:.1*tone(t,[523,659,784][min(2,int(t*6))])*math.exp(-t*3)),('reaction','Реакция гостя',.36,lambda t:.09*tone(t,440+200*t)*math.exp(-t*6))]
 for name,label,duration,fn in mapping:write(name,duration,fn)
 # Original 16-second loop, four bars, no recorded/third-party material.
 notes=[261.625565,329.627557,391.995436,493.883301,220,261.625565,329.627557,391.995436,174.614116,220,261.625565,329.627557,195.997718,246.941651,293.664768,391.995436]
 def music(t):
  beat=int(t/.5);local=t% .5;f=notes[beat%16];env=math.exp(-local*7)*(1-math.exp(-local*130));return .10*env*(tone(t,f)+.3*tone(t,f*2))+.035*tone(t,notes[(beat//8)*4%16]/2)*math.sin(math.pi*t/16)**2
 write('music',16,music)
 (AUDIO/'events.json').write_text(json.dumps([{'id':n,'event':l,'file':n+'.wav','duration':d} for n,l,d,_ in mapping]+[{'id':'music','event':'Музыка — отдельная петля','file':'music.wav','duration':16}],ensure_ascii=False,indent=2)+'\n')

def package():
 # One offline review page; images/audio embedded, no network, no game save access.
 images={k:base64.b64encode((OUT/(k+'.png')).read_bytes()).decode() for k in SCREENS}
 events=json.loads((AUDIO/'events.json').read_text())
 audio={e['id']:base64.b64encode((AUDIO/e['file']).read_bytes()).decode() for e in events}
 source='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Путь баристы · экраны и звук v1</title><style>*{box-sizing:border-box}body{margin:0;background:#101719;color:#f5ead8;font:16px system-ui}header,nav,section{max-width:1280px;margin:auto;padding:16px}h1{font-size:25px;margin:0 0 8px}p{color:#acb8b4;margin:8px 0}nav{display:flex;gap:8px;flex-wrap:wrap}button{font:inherit;border:1px solid #667571;border-radius:12px;padding:12px;background:#242e30;color:#f5ead8;cursor:pointer}button:focus-visible{outline:3px solid #e7b66d}#stage{position:relative;width:100%;aspect-ratio:16/9}#stage img{width:100%;display:block}#stage button{position:absolute;background:transparent;color:transparent;border:0;padding:0;border-radius:16px}#stage button:hover{box-shadow:0 0 0 2px #e7b66d inset}#settings{display:none;padding:20px;background:#242e30;border-radius:20px}label{display:block;margin:16px 0}input[type=range]{width:50%;accent-color:#e7b66d}audio{width:100%;max-width:400px}#sounds{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}.sample{padding:20px;border:1px solid #40504b;border-radius:18px}a{color:#e7b66d}.note{font-size:14px}#motion{width:100%;max-width:960px;border-radius:20px}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto}}</style><header><h1>Путь баристы · экраны и звук v1</h1><p>Материалы для твоей проверки. Демонстрационные суммы. Это макеты, не новая сборка игры.</p></header><nav id="nav"></nav><section><div id="stage"></div><p id="caption"></p><div id="settings"><label>Общая громкость <input id="master" type="range" min="0" max="1" step=".05" value=".75"></label><label>Музыка <input id="musicVolume" type="range" min="0" max="1" step=".05" value=".45"></label><label>Эффекты <input id="effects" type="range" min="0" max="1" step=".05" value=".8"></label><label><input type="checkbox" checked> Вибрация (макет переключателя)</label><p>Регуляторы меняют громкость образцов ниже. Настройки игры не затрагиваются.</p></div></section><section><h2>Готовность, перетап, возврат стакана и оплата</h2><img id="motion" alt="Шестисекундная демонстрация сигналов интерфейса"><p class="note">Сигналы показаны отдельно. Перенос стойки 09 и анимация героев остаются самостоятельными задачами.</p></section><section><h2>Послушать звук</h2><p>Синтезированные кандидаты. Музыка отдельно от эффектов. Нажми Play — автозапуска нет.</p><div id="sounds"></div></section><script>const IMAGES=__IMAGES__,LINKS=__LINKS__,AUDIO=__AUDIO__,EVENTS=__EVENTS__;const titles={start:'Главный экран',shop:'Магазин',perks:'Усиление',summary:'Удачная смена','summary-fail':'Цель не выполнена',settings:'Пауза и настройки','learn-0':'Обучение'};const stage=document.getElementById('stage');function show(k){if(!IMAGES[k])return;stage.replaceChildren();const im=new Image;im.src='data:image/png;base64,'+IMAGES[k];im.alt=titles[k]||k;stage.append(im);for(const link of LINKS[k]||[]){const b=document.createElement('button');b.setAttribute('aria-label',link.label);Object.assign(b.style,{left:link.x/16+'%',top:link.y/9+'%',width:link.w/16+'%',height:link.h/9+'%'});b.onclick=()=>show(link.target);stage.append(b)}document.getElementById('settings').style.display=k==='settings'?'block':'none';document.getElementById('caption').textContent=k.startsWith('learn-')?'Схема подсказок. Место игровой сцены займёт утверждённая стойка 09.':'Макет 1600 × 900. Показаны покупка жерновов и выбор лёгкого помола. Остальные карточки — для сравнения оформления.'}for(const[k,title]of Object.entries(titles)){const b=document.createElement('button');b.textContent=title;b.onclick=()=>show(k);document.getElementById('nav').append(b)}for(const e of EVENTS){const div=document.createElement('div');div.className='sample';const p=document.createElement('p');p.textContent=e.event;const a=document.createElement('audio');a.controls=true;a.preload='none';a.loop=e.id==='music';a.dataset.kind=e.id==='music'?'music':'effects';a.src='data:audio/wav;base64,'+AUDIO[e.id];a.onplay=()=>{for(const other of document.querySelectorAll('audio'))if(other!==a)other.pause()};div.append(p,a);document.getElementById('sounds').append(div)}function volume(){for(const a of document.querySelectorAll('audio'))a.volume=Number(document.getElementById('master').value)*Number(document.getElementById(a.dataset.kind==='music'?'musicVolume':'effects').value)}for(const id of ['master','musicVolume','effects'])document.getElementById(id).oninput=volume;volume();document.getElementById('motion').src='data:image/gif;base64,__GIF__';show('start');</script></html>'''
 for key,val in [('__IMAGES__',images),('__LINKS__',LINKS),('__AUDIO__',audio),('__EVENTS__',events)]:source=source.replace(key,json.dumps(val,ensure_ascii=False))
 source=source.replace('__GIF__',base64.b64encode((ANIM/'feedback-v1.gif').read_bytes()).decode());(OUT/'review.html').write_text(source)
 keys=['start','shop','perks','summary','settings','learn-4'];sheet=Image.new('RGB',(1640,1530),'#101719');d=ImageDraw.Draw(sheet)
 for i,key in enumerate(keys):
  x=20+(i%2)*810;y=20+(i//2)*505;sheet.paste(SCREENS[key].resize((790,444)),(x,y));d.text((x,y+456),{'start':'01 · Главный экран','shop':'02 · Магазин','perks':'03 · Усиление','summary':'04 · Итог смены','settings':'05 · Пауза / настройки','learn-4':'06 · Обучение'}[key],font=ImageFont.truetype(FONT,23),fill=GOLD)
 sheet.save(OUT/'screens-overview-v1.png')
 print(f'Created {len(SCREENS)} screens, 120 animation frames, {len(events)} audio samples; text bounds PASS ({len(measures)} labels)')

if __name__=='__main__':
 for p in [OUT,ANIM,AUDIO]:p.mkdir(parents=True,exist_ok=True)
 screens();animation();sounds();package()
