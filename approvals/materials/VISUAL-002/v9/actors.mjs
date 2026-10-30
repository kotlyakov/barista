/** Native SVG rigs. All facial channels, including eyelids, remain continuous. */
export const EMOTIONS = [
  {id:'neutral',label:'Нейтрально'}, {id:'happy',label:'Радость'},
  {id:'delighted',label:'Восторг'}, {id:'impatient',label:'Нетерпение'},
  {id:'unhappy',label:'Недовольство'}, {id:'angry',label:'Злость'}, {id:'disappointed',label:'Разочарование'},
  {id:'surprised',label:'Удивление'}
];
const NS='http://www.w3.org/2000/svg';
const FACE={
 neutral:{smile:0,open:0,brow:0,eye:1,tilt:0},
 happy:{smile:18,open:7,brow:5,eye:.72,tilt:3},
 delighted:{smile:25,open:20,brow:8,eye:.5,tilt:4},
 impatient:{smile:-6,open:1,brow:-5,eye:.56,tilt:-6},
 unhappy:{smile:-12,open:3,brow:-3,eye:.72,tilt:-8},
 angry:{smile:-16,open:10,brow:-7,eye:.6,tilt:-13},
 disappointed:{smile:-16,open:3,brow:6,eye:.63,tilt:10},
 surprised:{smile:0,open:27,brow:13,eye:1.48,tilt:0}
};
function el(tag,attrs={},parent){const n=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(attrs))n.setAttribute(k,v);if(parent)parent.appendChild(n);return n;}
function path(parent,d,fill,stroke='#130e0d',width=2.5){return el('path',{d,fill,stroke,'stroke-width':width,'stroke-linecap':'round','stroke-linejoin':'round'},parent);}
const mix=(a,b,t)=>a+(b-a)*t;
const smooth=t=>t*t*(3-2*t);
export function createActors(host){
 const defs=el('defs',{},host);
 const clip=el('clipPath',{id:'barista-body-clip'},defs);el('path',{d:'M -250 -200 H 250 V 1000 H 26 V 251 H -250 Z'},clip);
 const layer=el('g',{'data-character-rigs':'true'},host);
 const skin='#b96c45',lightSkin='#d68c5b',hair='#1b1515',cloth='#19191e';
 const actors={};let clock=0,paused=false,hairOverride=-Infinity;
 function build(id,x,y){
  const outer=el('g',{'data-actor':id},layer),motion=el('g',{},outer),body=el('g',{},motion),head=el('g',{},motion);
  const a={id,x,y,outer,motion,body,head,face:{...FACE.neutral},from:{...FACE.neutral},target:{...FACE.neutral},emotion:'neutral',progress:1,duration:1,nextBlink:2.6+Math.random()*4,blink:0,phase:Math.random()*6.28,present:id==='barista',arrival:-1};actors[id]=a;
  if(id==='barista'){

   path(body,'M -55 90 Q -112 105 -125 182 L -127 326 Q -99 374 -14 382 L 62 365 L 66 168 Q 59 113 22 97 Z',cloth);
   path(body,'M -64 98 L -28 163 L 21 164 L 32 111 L 49 125 L 39 180 L 56 370 L -84 379 L -75 177 L -90 119 Z','#38332b');
   path(body,'M -66 105 L -30 166 M 22 165 L 36 117','none','#89704b',7);
   el('rect',{x:-30,y:179,width:29,height:16,rx:2,fill:'#bc945c',stroke:'#1d1711','stroke-width':2,transform:'rotate(-12 -30 179)'},body);
   path(body,'M -104 148 Q -143 180 -119 267 L -96 329 Q -76 343 -54 323 L 30 277 L 79 270 L 99 253 Q 109 247 115 257 L 110 277 Q 118 281 110 291 L 87 302 L 41 305 L -48 358 Q -89 381 -118 346 L -147 277 L -143 205 Q -138 164 -104 148',cloth);
   a.nearForearm=path(body,'M -57 317 L 37 272 L 77 270 L 92 255 Q 99 249 105 254 L 102 272 L 114 271 Q 122 274 116 281 L 103 287 Q 114 292 102 299 L 79 304 L 43 303 L -48 351 Z',lightSkin);
   a.nearFingers=path(body,'M 84 276 L 102 272 M 84 285 L 106 280 M 83 294 L 101 288','none','#8b4a35',1.8);
   path(head,'M -19 57 L -34 101 Q -15 133 19 134 L 28 106 L 17 64 Z',lightSkin);
   a.pony=el('g',{},head);
   path(a.pony,'M -49 -36 Q -111 -75 -128 -26 Q -158 -7 -131 16 Q -153 69 -111 104 Q -123 68 -96 54 Q -100 96 -74 108 Q -84 59 -56 43 Z','#251919');
   path(a.pony,'M -88 -33 Q -128 -25 -112 28 M -104 8 Q -126 50 -110 76','none','#4a2b23',3);
   path(head,'M -45 -52 Q 6 -89 47 -49 Q 60 -29 56 -2 L 64 22 L 80 34 Q 84 40 69 44 L 65 64 Q 60 86 41 88 L 8 71 Q -12 64 -23 36 L -44 17 Z',lightSkin);
   path(head,'M 45 75 L 38 80 L 17 70','none','#b96c45',2);
   path(head,'M -54 -5 Q -76 -27 -59 -64 Q -30 -99 26 -83 Q 61 -77 73 -47 L 77 -8 L 65 8 L 56 -31 Q 46 -6 13 5 Q 23 -17 28 -28 Q -1 -2 -37 9 L -36 40 L -52 21 Z','#281b18');
   path(head,'M -54 -49 Q -10 -80 40 -62 M -46 -25 Q -9 -27 20 -51 M 44 -47 Q 60 -30 64 -14','none','#513026',3);
   path(head,'M -32 11 Q -51 -4 -51 17 Q -49 36 -33 36',lightSkin);
   path(head,'M -39 14 Q -46 9 -44 23 L -38 24','none','#88442f',2);
   el('ellipse',{cx:-38,cy:40,rx:6,ry:10,fill:'none',stroke:'#b08c53','stroke-width':2},head);
   path(head,'M -10 7 Q -27 33 -16 72','none','#231817',6);
   a.eyeX=43;a.eyeY=15;a.mouthX=48;a.mouthY=60;a.eyeWidth=10;a.right=true;
  }else if(id==='beard'){
   // A fitted jacket and separate sleeve shapes replace the compressed block torso.
   path(body,'M -8 90 Q -58 108 -76 159 L -86 326 Q 29 343 167 325 L 153 211 Q 143 154 106 125 L 62 91 Z','#20232b');
   path(body,'M 8 105 L 43 133 L 74 106 L 102 130 L 69 180 L 37 159 L 7 182 L -35 137 Z','#383b43');
   path(body,'M -41 123 L 7 102 L 37 151 L 17 175 L -1 145 L -30 163 Z','#292d36');
   path(body,'M 76 112 L 104 126 L 73 178 L 45 158 Z','#151a23');
   path(body,'M 95 163 Q 146 211 158 320 L 112 325 L 88 235 Z','#171b23','none');
   path(body,'M 60 161 Q 104 147 124 180 Q 146 215 133 253 Q 116 287 80 280 L -37 232 L -70 231 L -78 207 L -47 192 L -15 204 L 70 230 L 66 186 Z','#252a33');
   path(body,'M -37 232 L -70 230 Q -85 226 -86 216 L -91 210 Q -95 201 -84 199 Q -87 188 -75 187 L -66 182 Q -57 179 -50 187 L -32 194 L -12 210 Z',lightSkin);
   path(body,'M -75 201 L -57 208 M -78 208 L -60 215 M -74 216 L -58 222','none','#96583d',1.7);
   path(body,'M -14 214 L -29 240 L -39 235 L -24 208 Z','#131921');
   path(body,'M 86 179 Q 106 197 111 221 M 128 244 Q 115 264 92 264 M 18 270 L 13 322 M -63 269 L -70 310','none','#46505c',2.3);
   path(body,'M 40 171 L 40 200 M 36 288 L 34 329','none','#6b6b67',1.5);
   path(head,'M 7 48 L -3 102 L 30 143 L 76 111 L 56 42 Z',skin);
   path(head,'M -38 -56 Q 2 -87 48 -54 L 63 -9 L 63 39 Q 51 74 13 81 L -28 68 L -50 37 L -63 24 L -78 17 Q -90 11 -74 2 L -61 -7 L -55 -34 Z',lightSkin);
   path(head,'M 25 13 Q 67 -13 69 -51 Q 59 -99 9 -105 L -18 -98 L -36 -105 L -32 -92 Q -66 -103 -80 -80 L -58 -83 Q -84 -68 -74 -46 L -56 -56 L -49 -32 L -29 -11 L 7 8 L 20 50 L 52 61 L 72 38 L 80 -7 Q 99 -51 60 -81',hair);
   path(head,'M -51 -68 Q -9 -90 36 -62 M -23 -80 Q 20 -61 53 -29 M 19 -42 Q 57 -18 60 7','none','#332529',3);
   path(head,'M 34 9 Q 47 -9 59 2 Q 72 22 53 37 L 41 37',lightSkin);
   path(head,'M 49 7 Q 62 7 52 26 L 46 24','none','#8a4935',2);
   path(head,'M -62 34 Q -39 28 -19 43 L 8 31 L 23 10 L 28 44 Q 19 81 -18 85 Q -56 85 -66 60 Z','#201916');
   path(head,'M -58 66 Q -24 90 7 59','none','#3d2d25',2);
   path(head,'M -54 -68 Q -27 -83 2 -78 M -17 -70 Q 17 -59 41 -37 M 33 -38 Q 50 -22 56 -3','none','#4a3433',2.5);
   path(head,'M -58 52 L -54 60 M -42 69 L -39 75 M -24 72 L -24 78 M -4 59 L -8 68 M 13 41 L 9 52','none','#473329',1.8);
   path(head,'M -59 -24 Q -66 -12 -65 -4 M -70 13 L -75 13','none','#945539',1.7);
   a.eyeX=-46;a.eyeY=-4;a.mouthX=-45;a.mouthY=49;a.eyeWidth=11;
  }else{
   path(body,'M -57 91 Q -115 104 -128 162 L -144 264 L -115 289 L -112 394 Q -20 435 126 398 L 136 280 L 163 257 L 142 165 Q 125 109 58 91 Z','#8c3e29');
   // Leaves and broad five-petal blossoms are actual shirt geometry.
   const flowers=[[-87,147,21],[-28,169,25],[70,145,23],[112,211,22],[-97,245,23],[3,251,28],[70,302,26],[-51,337,27],[103,365,21],[-88,391,20],[7,407,23]];
   for(const [fx,fy,r] of flowers){const f=el('g',{transform:`translate(${fx} ${fy})`},body);for(let k=0;k<5;k++)el('ellipse',{cx:0,cy:-r*.56,rx:r*.38,ry:r*.69,fill:'#bb6b37',stroke:'#7d3b28','stroke-width':1.3,transform:`rotate(${k*72})`},f);el('circle',{r:r*.18,fill:'#683c27'},f);}
   for(const [lx,ly] of [[-100,193],[-48,220],[47,211],[111,282],[-74,304],[17,345],[67,390],[-25,116]]){path(body,`M ${lx} ${ly} q -23 -26 -33 0 q 15 8 33 0 q 25 -31 35 -6 q -12 15 -35 6`,'#285451','#1d3534',1.5);}
   const shirtShade=path(body,'M 107 133 Q 151 190 136 281 L 126 398 Q 95 407 75 408 L 80 283 Q 112 237 107 133 Z','#432d29','none');shirtShade.setAttribute('opacity','.28');
   path(body,'M 73 191 Q 96 195 119 188 L 113 230 Q 92 242 76 230 Z','none','#b76b45',2);
   path(body,'M -111 265 L -82 279 M 125 276 L 150 267 M -70 380 Q -5 402 66 395','none','#c37a51',2);
   for(const by of [180,235,291,348,397])el('circle',{cx:16-(by-180)*.02,cy:by,r:3.2,fill:'#dabf83',stroke:'#5e3827','stroke-width':1.2},body);
   path(body,'M -57 93 L -27 142 L 5 116 L 31 149 L 58 93 L 83 108 L 56 172 L 20 145 L 12 420','none','#341f1c',3);
   path(body,'M -57 92 L -26 129 L 5 112 L 30 139 L 58 91 L 23 69 L -32 67 Z',skin);
   path(body,'M -131 262 L -113 279 L -110 337 Q -105 365 -83 369 L -71 338 L -75 293 L -86 276',skin);
   path(body,'M 137 268 L 162 258 Q 168 335 120 378 L 96 361 Q 122 317 123 282 Z',skin);

   path(body,'M 100 361 L 117 378 L 86 421 M -73 359 L -85 406','none','#0f151c',6);
   path(head,'M -36 55 L -37 99 Q -10 124 25 106 L 48 73 L 38 45 Z',skin);
   path(head,'M -66 -20 Q -71 -80 -25 -98 Q 18 -116 56 -81 Q 80 -54 68 -8 L 64 47 Q 48 91 3 91 Q -39 91 -57 59 L -68 28 Q -96 25 -96 9 Q -96 -8 -66 -9 Z',lightSkin);
   path(head,'M 50 -19 Q 74 -33 76 -9 Q 75 14 59 22 L 48 17',skin);
   path(head,'M 60 -13 Q 70 -17 65 4 L 57 8','none','#884831',2);
   path(head,'M -67 -9 Q -96 -9 -96 9 Q -95 26 -71 26 L -58 19','none','#8c4632',2.5);
   path(head,'M 60 32 Q 38 82 1 83','none','#a35a3c',2.5);
   const scalp=path(head,'M -53 -43 Q -40 -91 -5 -93 Q 27 -98 48 -76 Q 11 -94 -18 -74 Q -39 -61 -53 -43 Z','#ebb17a','none');scalp.setAttribute('opacity','.28');
   path(head,'M 41 24 Q 38 51 13 62','none','#b56d47',2);
   path(head,'M -78 21 L -70 19 M -55 63 Q -37 79 -15 80','none','#995334',1.6);
   el('ellipse',{cx:-83,cy:4,rx:6,ry:4,fill:'#e29a65',opacity:.5},head);
   a.eyeX=-44;a.eyeY=-22;a.mouthX=-40;a.mouthY=39;a.eyeWidth=12;
   // Far eye gives the bald customer's three-quarter view its friendly depth.
   a.farEye=el('ellipse',{cx:-68,cy:-27,rx:4,ry:7,fill:'#e8c09a',stroke:'#2a1a14','stroke-width':1.8},head);
   a.farPupil=el('ellipse',{cx:-70,cy:-26,rx:2,ry:4,fill:'#261711'},head);
  }
  const face=el('g',{'data-face':id},head);
  a.eye=el('path',{fill:'#f2dcb8',stroke:'#291912','stroke-width':2.8},face);
  a.pupil=el('ellipse',{fill:'#251812',rx:3.7,ry:7},face);
  if(id!=='barista')a.glint=el('ellipse',{rx:1.1,ry:1.4,fill:'#f6e2bd'},face);
  a.lid=el('path',{fill:'none',stroke:'#2a1914','stroke-width':2.7,'stroke-linecap':'round'},face);
  a.brow=el('path',{fill:'none',stroke:id==='barista'?'#2a1713':'#201512','stroke-width':id==='barista'?4.5:6,'stroke-linecap':'round'},face);
  a.mouth=el('path',{'data-mouth':id,fill:'#49271f',stroke:id==='beard'?'#dba27d':'#48271d','stroke-width':id==='beard'?3.4:2.8,'stroke-linecap':'round'},face);
  const mouthClip=el('clipPath',{id:'mouth-clip-'+id,clipPathUnits:'userSpaceOnUse'},defs);a.mouthClip=el('path',{},mouthClip);
  a.teeth=el('path',{fill:'#eedfc4','stroke':'none','data-teeth':id,'clip-path':'url(#mouth-clip-'+id+')'},face);
  a.cheek=el('path',{fill:'none',stroke:id==='beard'?'#c68a62':'#91482f','stroke-width':2,'stroke-linecap':'round'},face);
  a.lowerLip=el('path',{fill:'none',stroke:id==='beard'?'#bd815c':'#9b5137','stroke-width':2,'stroke-linecap':'round'},face);
  if(id==='barista') path(face,'M 47 9 L 56 8 M 48 12 L 57 12','none','#261713',1.8);
  outer.setAttribute('visibility',a.present?'visible':'hidden');return a;
 }
 // Far customer first: the foreground customer naturally occludes his shirt.
 build('hawaii',1400,225);build('barista',299,259);build('beard',1120,315);
 // Articulated legs stay in the world even when the foreground counter occludes them.
 for(const id of ['beard','hawaii']){
  const a=actors[id];a.scale=id==='beard'?1.04:.83;
  a.legs=el('g',{'data-legs':id},a.motion);a.motion.insertBefore(a.legs,a.body);a.feet=[];
  const beard=id==='beard',hip=beard?335:410,knee=beard?428:520,ankle=beard?525:635;

  path(a.legs,beard?'M -81 318 L 161 318 L 145 369 L -80 369 Z':'M -110 395 Q -20 419 126 394 L 120 445 L -117 445 Z',beard?'#22232b':'#1c2227');
  for(const [x,w] of (beard?[[-75,83],[50,95]]:[[-119,79],[-11,123]])){
   const leg=el('g',{'data-leg':String(a.feet.length)},a.legs),shin=el('g',{'data-knee':'true'},leg);
   path(leg,`M ${x} ${hip} L ${x+w} ${hip} L ${x+w-5} ${knee+12} L ${x-2} ${knee+12} Z`,beard?'#24252e':'#1c2227');leg.appendChild(shin);
   path(shin,`M ${x-2} ${knee} L ${x+w-5} ${knee} L ${x+w-15} ${ankle} L ${x-8} ${ankle} Z`,beard?'#24252e':'#1c2227');
   path(shin,`M ${x-8} ${ankle-8} Q ${x-34} ${ankle-5} ${x-34} ${ankle+15} L ${x+w-12} ${ankle+15} L ${x+w-14} ${ankle-6} Z`,beard?'#131519':'#33281f');
   path(shin,`M ${x-26} ${ankle+11} H ${x+w-17}`,'none',beard?'#6c625a':'#c5a77f',3);
   a.feet.push({node:leg,shin,x:x+w/2,pivot:hip,knee,sole:ankle+15});
  }
 }
 actors.barista.scale=1.08;
 function drawFace(a,blink){
  const f=a.face,x=a.eyeX,y=a.eyeY,w=a.eyeWidth*1.13;
  const h=Math.max(.25,8.5*f.eye*(1-blink));
  a.eye.setAttribute('d',`M ${x-w} ${y} Q ${x-1} ${y-h*1.3} ${x+w} ${y} Q ${x} ${y+h} ${x-w} ${y} Z`);
  a.pupil.setAttribute('cx',x+(a.right?3:-3));a.pupil.setAttribute('cy',y);a.pupil.setAttribute('ry',Math.max(.1,h*.79));a.pupil.setAttribute('rx',Math.max(.1,3.5*(1-blink)));
  if(a.glint){a.glint.setAttribute('cx',x-4);a.glint.setAttribute('cy',y-2);a.glint.setAttribute('opacity',Math.max(0,1-blink));}
  a.lid.setAttribute('d',`M ${x-w} ${y} Q ${x} ${y-h*1.3} ${x+w} ${y}`);
  const by=y-18-f.brow;
  a.brow.setAttribute('d',`M ${x-w-2} ${by+f.tilt} Q ${x} ${by-5} ${x+w+2} ${by-f.tilt}`);
  const mx=a.mouthX,my=a.mouthY,mw=a.id==='hawaii'?23:a.id==='barista'?15:21,open=f.open;
  a.mouth.setAttribute('d',`M ${mx-mw} ${my} Q ${mx} ${my+f.smile} ${mx+mw} ${my-1} Q ${mx} ${my+f.smile+open} ${mx-mw} ${my} Z`);
  a.mouthClip.setAttribute('d',a.mouth.getAttribute('d'));
  const tx=mw*.76,left=my+.2112*f.smile-.0144,right=my+.2112*f.smile-.7744,control=my+.7888*f.smile-.1056,thickness=Math.min(5,open*.38);
  a.teeth.setAttribute('d',`M ${mx-tx} ${left} Q ${mx} ${control} ${mx+tx} ${right} L ${mx+tx} ${right+thickness} Q ${mx} ${control+thickness} ${mx-tx} ${left+thickness} Z`);
  a.teeth.setAttribute('opacity',Math.max(0,Math.min(1,f.smile/16)*Math.min(1,open/7)));
  a.cheek.setAttribute('d',`M ${x-w-4} ${y+17} Q ${x-w-10} ${y+22} ${x-w-7} ${y+29}`);
  a.cheek.setAttribute('opacity',Math.min(.8,Math.abs(f.smile)/23));
  a.lowerLip.setAttribute('d',`M ${mx-mw*.5} ${my+Math.max(2,f.smile+open)+4} Q ${mx} ${my+Math.max(3,f.smile+open)+6} ${mx+mw*.5} ${my+Math.max(2,f.smile+open)+3}`);
  if(a.farEye){a.farEye.setAttribute('ry',Math.max(.3,6.5*f.eye*(1-blink)));a.farPupil.setAttribute('ry',Math.max(.1,4*f.eye*(1-blink)));a.farPupil.setAttribute('rx',Math.max(.1,2*(1-blink)));}
 }
 function tick(dt){
  if(paused)return;dt=Math.min(.5,Math.max(0,Number(dt)||0));clock+=dt;
  for(const a of Object.values(actors)){
   if(a.progress<1){a.progress=Math.min(1,a.progress+dt/a.duration);const t=smooth(a.progress);for(const k in a.face)a.face[k]=mix(a.from[k],a.target[k],t);}
   let blink=0;
   if(clock>=a.nextBlink){a.blink+=dt;const p=a.blink/(a.blinkDuration||.18);blink=p<.42?p/.42:Math.max(0,(1-p)/.58);if(p>=1){a.blink=0;a.blinkDuration=.18;a.nextBlink=clock+3+Math.random()*4;}}
   drawFace(a,blink);
   if(!a.present)continue;
   let x=a.x,y=a.y,scale=1,gait=0,walkPhase=0;
   if(a.arrival>=0){
    const delay=a.id==='beard'?.05:.9,duration=a.id==='beard'?6.8:7.4;
    const elapsed=Math.max(0,clock-a.arrival-delay),p=Math.min(1,elapsed/duration),t=smooth(p);
    x=mix(1510,a.x,t);scale=mix(.38,1,t);
    // Interpolate the floor contact point, not the head: growing perspective cannot launch the feet.
    const height=(a.id==='beard'?540:650)*a.scale;
    const floor=mix(178+.38*height,a.y+height,t);y=floor-height*scale;
    gait=smooth(Math.min(1,elapsed/.5))*smooth(Math.min(1,(duration-elapsed)/.6));walkPhase=elapsed*Math.PI*1.8;
    if(p===1){a.arrival=-1;gait=0;}
   }
   if(a.departure!=null){
    const elapsed=clock-a.departure,p=Math.min(1,elapsed/5),t=smooth(p);
    x=mix(a.x,1655,t);scale=mix(1,.36,t);const height=(a.id==='beard'?540:650)*a.scale;
    y=mix(a.y+height,155+.36*height,t)-height*scale;
    gait=smooth(Math.min(1,elapsed/.5))*smooth(Math.min(1,(5-elapsed)/.6));walkPhase=elapsed*Math.PI*1.8;
    if(p===1){a.present=false;a.outer.setAttribute('visibility','hidden');}
   }
   a.pose={x,y,scale:scale*a.scale};
   a.outer.setAttribute('transform',`translate(${x.toFixed(2)} ${y.toFixed(2)}) scale(${(scale*a.scale).toFixed(4)})`);
   const phase=(clock+a.phase)%9.5;
   const shift=phase<3.4?Math.sin(phase/3.4*Math.PI*2)*4:0;
   const sway=(1-gait)*(Math.sin(clock*.73+a.phase)*1.2+shift)+gait*Math.sin(walkPhase)*1.4;
   for(let i=0;i<(a.feet?.length||0);i++){
    const f=a.feet[i],stride=Math.sin(walkPhase+i*Math.PI),swing=Math.max(0,stride),idle=(i?shift:-shift)*(1-gait);
    const lift=gait*swing*7+Math.max(0,idle)*.3,angle=gait*stride*14+idle*.25;
    const plant=gait*(stride<=0?(f.sole-f.pivot)*(1-Math.cos(angle*Math.PI/180)):0);
    f.node.setAttribute('transform',`translate(0 ${plant-lift}) rotate(${angle} ${f.x} ${f.pivot})`);
    f.shin.setAttribute('transform',`rotate(${-gait*swing*23} ${f.x} ${f.knee})`);
   }
   a.sway=sway;
   const breathing=Math.sin(clock*1.05+a.phase)*.7*(1-gait),settle=-Math.abs(Math.sin(walkPhase))*gait*.65;
   a.motion.setAttribute('transform',`translate(${sway.toFixed(2)} ${(breathing+settle).toFixed(2)}) rotate(${(sway*.08).toFixed(3)} 0 100)`);
   a.head.setAttribute('transform',`rotate(${(Math.sin(clock*.58+a.phase)*.35*(1-gait)).toFixed(3)} 0 62)`);
   if(a.pony){const cycle=(clock+a.phase)%10.7;const natural=cycle<3.4?Math.sin(Math.PI*cycle/3.4)**2:0;const hp=(clock-hairOverride)/3.4;const pulse=Math.max(natural,hp>=0&&hp<1?Math.sin(Math.PI*hp)**2:0);a.pony.setAttribute('transform',`rotate(${(Math.sin(clock*2.1)*2.1*pulse).toFixed(3)} -48 -25)`);}
  }
 }
 tick(0);
 return {
  tick,
  setEmotion(id,emotion,durationMs=1100){const a=actors[id];if(!a||!FACE[emotion])return false;a.from={...a.face};a.target={...FACE[emotion]};a.emotion=emotion;a.duration=Math.max(.05,durationMs/1000);a.progress=0;return true;},
  enter(){for(const id of ['beard','hawaii']){const a=actors[id];a.present=true;a.arrival=clock;a.departure=null;a.heldCup?.remove();a.heldCup=null;a.outer.setAttribute('visibility','visible');}tick(0);},
  leave(id){const a=actors[id];if(a&&a.departure==null)a.departure=clock;},
  pose(id){return actors[id]?.pose;},
  reach(value){for(const key of ['nearForearm','nearFingers'])actors.barista[key].setAttribute('visibility',value?'hidden':'visible');},
  handOrigin(){const a=actors.barista,p=a.pose;return {x:p.x+(-57+(a.sway||0))*p.scale,y:p.y+334*p.scale};},
  holdCup(id,recipe){const a=actors[id];if(!a)return;a.heldCup?.remove();const c=el('g',{transform:id==='beard'?'translate(-100 184)':'translate(-99 320)'},a.motion);a.heldCup=c;const fill={cappuccino:'#588a77',espresso:'#704f42',latte:'#a77b58'}[recipe];path(c,'M-21 0 L-15 45 Q0 52 15 45 L21 0 Z','#e8d6b7','#edddc0',2);path(c,'M-18 13 L-15 34 Q0 40 15 34 L18 13 Z',fill,'none');el('ellipse',{cx:0,cy:0,rx:22,ry:6,fill:'#e9d6b7',stroke:'#f5e6cb','stroke-width':2},c);},
  isPresent(id){return Boolean(actors[id]?.present);},
  isArrived(id){const a=actors[id];return Boolean(a?.present&&a.arrival<0&&a.departure==null);},
  blink(id){const a=actors[id];if(a){a.nextBlink=clock;a.blink=0;a.blinkDuration=.28;}},
  swayHair(){hairOverride=clock;},
  setPaused(value){paused=Boolean(value);},
  getEmotion(id){return actors[id]?.emotion??null;}
 };
}
