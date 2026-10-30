// Original quiet procedural cafe bed and bounded appliance/coin sounds.
// No external recordings, downloads or audio SDKs.
export function createCafeAudio(){
 let ctx,master,musicTimer,enabled=true,paused=true,beat=0,lastMachine=-1;
 const notes=[[261.63,329.63,392],[220,261.63,329.63],[174.61,220,261.63],[196,246.94,293.66]];
 function tone(freq,when,length,gain=.025){
  const o=ctx.createOscillator(),v=ctx.createGain();o.type='sine';o.frequency.value=freq;
  v.gain.setValueAtTime(0,when);v.gain.linearRampToValueAtTime(gain,when+.015);v.gain.exponentialRampToValueAtTime(.0001,when+length);
  o.connect(v).connect(master);o.start(when);o.stop(when+length+.02);
 }
 function music(){if(!ctx||paused||!enabled||ctx.state!=='running')return;const chord=notes[Math.floor(beat/8)%4],n=chord[beat%3];tone(n,ctx.currentTime,.8,.018);if(beat%4===0)tone(chord[0]/2,ctx.currentTime,1.6,.016);beat++;}
 async function unlock(){
  if(!ctx){const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;ctx=new Audio();master=ctx.createGain();master.gain.value=.45;master.connect(ctx.destination);musicTimer=setInterval(music,500);}
  if(enabled&&!paused)try{await ctx.resume();}catch{}
 }
 function sync(){if(!ctx)return;if(enabled&&!paused){void ctx.resume().catch(()=>{});master.gain.setTargetAtTime(.45,ctx.currentTime,.03);}else{master.gain.setTargetAtTime(0,ctx.currentTime,.02);void ctx.suspend().catch(()=>{});}}
 return {unlock,setEnabled(v){enabled=v;sync();},setPaused(v){paused=v;sync();},
  machine(step){if(!ctx||!enabled||paused||ctx.state!=='running'||ctx.currentTime-lastMachine<.22)return;lastMachine=ctx.currentTime;
   const n=ctx.sampleRate*.22,buffer=ctx.createBuffer(1,n,ctx.sampleRate),data=buffer.getChannelData(0);for(let i=0;i<n;i++)data[i]=(Math.random()*2-1)*.06*Math.sin(Math.PI*i/n);
   const source=ctx.createBufferSource(),filter=ctx.createBiquadFilter();source.buffer=buffer;filter.type='lowpass';filter.frequency.value=[500,1100,2200][step];source.connect(filter).connect(master);source.start();source.stop(ctx.currentTime+.23);
  },coins(){if(ctx&&enabled&&!paused&&ctx.state==='running'){tone(1046.5,ctx.currentTime,.16,.07);tone(1568,ctx.currentTime+.07,.2,.05);}},
  dispose(){clearInterval(musicTimer);if(ctx)void ctx.close();}
 };
}
