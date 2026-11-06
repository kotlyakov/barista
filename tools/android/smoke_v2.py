"""Actual Android touch/restart validation of Service v2 at the build's exact SHA."""
import hashlib,json,os,re,struct,subprocess,time
from pathlib import Path
PACKAGE='org.kotlyakov.barista.emulator'
OUT=Path('artifacts/android-runtime-v2');OUT.mkdir(parents=True,exist_ok=True)
source=json.loads(Path('artifacts/android-input/source.json').read_text())
assert source['source_commit']==os.environ['BARISTA_EXPECTED_SOURCE_SHA'],'Wrong APK source'
width=1600;height=900;legacy_root='files/saves'
def adb(*args,binary=False):
 return subprocess.check_output(['adb',*args],text=not binary,stderr=subprocess.STDOUT,timeout=30)
def wait(read,predicate,seconds=12):
 deadline=time.monotonic()+seconds;last=None
 while time.monotonic()<deadline:
  last=read()
  if predicate(last):return last
  time.sleep(.3)
 raise AssertionError(f'Condition timeout: {last}')
def read_state(legacy=False):
 global legacy_root
 try:paths=adb('shell','run-as',PACKAGE,'find','files','-name','slot*.json').splitlines()
 except subprocess.CalledProcessError:return None
 candidates=[]
 for path in paths:
  path=path.strip()
  if legacy:
   if path not in [legacy_root+'/slot0.json',legacy_root+'/slot1.json']:continue
  elif not re.search(r'/v2/slot[01]\.json$',path):continue
  envelope=json.loads(adb('shell','run-as',PACKAGE,'cat',path))
  payload=envelope['payload'];sequence=int(envelope['sequence'])
  signed=payload if legacy else '2\n'+str(sequence)+'\n'+payload
  assert hashlib.sha256(signed.encode()).hexdigest()==envelope['sha256'],'Save checksum'
  if not legacy:legacy_root=str(Path(path).parent.parent)
  candidates.append(envelope)
 if not candidates:return None
 return json.loads(max(candidates,key=lambda x:x['sequence'])['payload'])
def shot(name):
 data=adb('exec-out','screencap','-p',binary=True);assert data.startswith(b'\x89PNG')
 (OUT/(name+'.png')).write_bytes(data);return struct.unpack('>II',data[16:24])
def point(x,y):
 scale=min(width/1600,height/900);return str(round((width-1600*scale)/2+x*scale)),str(round((height-900*scale)/2+y*scale))
def tap(x,y):adb('shell','input','tap',*point(x,y))
def drag(x,y):adb('shell','input','swipe',*point(650,760),*point(x,y),'400')
def launch(legacy=False):
 global width,height
 component=next(x.strip() for x in adb('shell','cmd','package','resolve-activity','--brief','-c','android.intent.category.LAUNCHER',PACKAGE).splitlines() if '/' in x)
 adb('shell','am','start','-W','-n',component)
 wait(lambda:read_state(legacy),lambda s:s is not None,20);time.sleep(1)
 # Debug Godot engine can show a first-launch dialog on emulator images.
 adb('shell','uiautomator','dump','/sdcard/barista-v2-window.xml')
 xml=adb('shell','cat','/sdcard/barista-v2-window.xml')
 import xml.etree.ElementTree as ET
 for element in ET.fromstring(xml).iter('node'):
  if element.get('text')=='Got it':
   b=list(map(int,re.findall(r'\d+',element.get('bounds',''))));adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2))
 width,height=shot('startup');assert width>height
 tap(20,200);time.sleep(.25)
def stop():adb('shell','am','force-stop',PACKAGE)
def app_write(relative,data):
 assert re.fullmatch(r'[a-zA-Z0-9_./-]+',relative)
 adb('shell','run-as',PACKAGE,'mkdir','-p',str(Path(relative).parent))
 command=f"run-as {PACKAGE} sh -c 'cat > {relative}'"
 subprocess.run(['adb','shell',command],input=data,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
def install_legacy(name):
 stop();adb('shell','pm','clear',PACKAGE)
 old=json.loads(Path('game/tests/fixtures/v1/'+name).read_text());payload=json.dumps(old,ensure_ascii=False,separators=(',',':'))
 envelope=json.dumps({'schema_version':1,'sequence':1,'payload':payload,'sha256':hashlib.sha256(payload.encode()).hexdigest()},ensure_ascii=False).encode()
 app_write(legacy_root+'/slot0.json',envelope);return old,envelope
try:
 adb('logcat','-c');launch();initial=wait(read_state,lambda s:s and 'economy'in s)
 assert initial['shift']['phase']=='PREPARING'
 tap(325,445);assert read_state()['money']==0 and read_state()['economy']['choice']=='','Unaffordable offer'
 shot('01-preparation');tap(1290,815);started=wait(read_state,lambda s:s['shift']['phase']=='RUNNING')
 tap(1490,60);paused=read_state();time.sleep(1.3);assert read_state()['clock']==paused['clock'],'Menu active pause'
 tap(800,525);wait(read_state,lambda s:s['preferences']['muted'] is False)
 tap(800,625);before=read_state();tap(240,815);tap(849,411);time.sleep(.5);shot('02-training')
 assert read_state()==before,'Practice changes actual main save'
 tap(1330,830);tap(800,425)
 tap(849,411);milk=wait(read_state,lambda s:s['cup']['taps'][2]==1);assert milk['cup']['taps'][0]==0
 tap(540,520);assert read_state()['cup']['taps'][1]==0,'Whole beans must be rejected'
 shot('03-milk-first');drag(300,200);time.sleep(.3);tap(180,650)
 continued=wait(read_state,lambda s:s['cup']['taps'][0]==1);assert continued['cup']['taps'][2]==1,'Miss loses cup'
 for station,(x,y) in enumerate([(180,650),(540,520),(849,411)]):
  saved=read_state()
  for _ in range(int(saved['cup']['targets'][station]-saved['cup']['taps'][station])):tap(x,y)
 saved=read_state();assert saved['cup']['taps']==saved['cup']['targets']
 first=saved['visits'][0];assert first['state']=='WAITING';drag(1009,470)
 payment=wait(read_state,lambda s:any(p['state']=='PENDING' for p in s['payments']));receipt=next(p for p in payment['payments'] if p['state']=='PENDING');balance=payment['money'];shot('04-payment')
 stop();launch();restored=read_state();assert any(p['id']==receipt['id'] and p['state']=='PENDING' for p in restored['payments']),'Pending payment restart'
 tap(1009,580);collected=wait(read_state,lambda s:s['money']==balance+receipt['amount']);assert len(collected['profiles'][first['customer_id']]['history'])==1
 stop();launch();wait(read_state,lambda s:any(v['state']=='WAITING' for v in s['visits']),35);stop();launch();tap(1490,60);saved=read_state();assert saved['money']==collected['money'] and saved['profiles']==collected['profiles'],'Collected money/history restart'
 # Relaunch assigns fixed slots in current visit-array order. Stay paused while choosing.
 waiting=next((i,v) for i,v in enumerate(saved['visits']) if v['state']=='WAITING')
 slot,visitor=waiting;tap(800,425);tap(180,650);drag(1009+126*slot,470)
 second=wait(read_state,lambda s:any(p['visit_id']==visitor['id'] and p['state']=='PENDING' for p in s['payments']))
 receipt2=next(p for p in second['payments'] if p['visit_id']==visitor['id']);tap(1009+126*slot,580)
 wait(read_state,lambda s:s['money']==collected['money']+receipt2['amount'])
 adb('shell','input','keyevent','KEYCODE_HOME');time.sleep(.6);background=read_state();time.sleep(1.2);assert read_state()['clock']==background['clock'],'Background must pause'
 launch();tap(800,425)
 five=wait(read_state,lambda s:len(s['visits'])==5,110);shot('05-five-guests')
 (OUT/'five-meminfo.txt').write_text(adb('shell','dumpsys','meminfo',PACKAGE))
 def perf():
  try:return json.loads(adb('shell','run-as',PACKAGE,'cat',legacy_root+'/v2-performance.json'))
  except (subprocess.CalledProcessError,json.JSONDecodeError):return None
 performance=wait(perf,lambda p:p and p['visits']==5,30);(OUT/'performance.json').write_text(json.dumps(performance))
 assert performance['fps']>0 and performance['process_ms']>=0
 summary=wait(read_state,lambda s:s['shift']['phase']=='SUMMARY',360);assert summary['money']>=100 and len(summary['visits'])==0;shot('06-summary')
 tap(800,752);prep=wait(read_state,lambda s:s['shift']['day_number']==2);assert prep['shift']['phase']=='PREPARING'
 tap(210,257);prices={'warmth':100,'change':80,'aroma':60,'focus':120};index=min(range(3),key=lambda i:prices[prep['economy']['offers'][i]]);perk=prep['economy']['offers'][index]
 tap(325+490*index,445);bought=wait(read_state,lambda s:s['economy']['choice']==perk);assert bought['money']==prep['money']-prices[perk]
 tap(325+490*((index+1)%3),445);assert read_state()['money']==bought['money'],'Second perk purchase'
 tap(1290,815);day2=wait(read_state,lambda s:s['shift']['phase']=='RUNNING');assert day2['shift']['day_number']==2
 stop();launch();assert read_state()['money']==day2['money'] and read_state()['shift']['day_number']==2
 (OUT/'career-final.json').write_text(json.dumps(read_state(),ensure_ascii=False,indent=2))
 old,envelope=install_legacy('summary.json');launch();migrated=wait(read_state,lambda s:s and s.get('migration',{}).get('candidate_only') is False)
 assert migrated['money']==4777,'Actual Android migration refund/premium'
 assert adb('shell','run-as',PACKAGE,'cat',legacy_root+'/slot0.json').encode().strip()==envelope.strip()
 assert adb('shell','run-as',PACKAGE,'cat',legacy_root+'/v1-before-v2/slot0.json').encode().strip()==envelope.strip()
 tap(506,257);tap(535,407);wait(read_state,lambda s:s['upgrades']['grind']==2 and s['money']==3977)
 stop();launch();assert read_state()['money']==3977;shot('07-migrated-progress')
 old,_=install_legacy('closing.json');launch(legacy=True);assert read_state() is None
 current=read_state(True);assert current['shift']['mode']=='CLOSING'
 for station,(x,y) in enumerate([(180,650),(540,520),(849,411)]):
  current=read_state(True)
  for _ in range(int(current['brew']['targets'][station]-current['brew']['taps'][station])):tap(x,y)
 drag(1110,450);old_payment=wait(lambda:read_state(True),lambda s:s['order']['state']=='PAYMENT');tap(955,610)
 completed=wait(read_state,lambda s:s and s.get('migration',{}).get('candidate_only') is False)
 assert completed['money']==old['money']+old_payment['order']['payment']['amount']+3800,'Legacy active completion migration'
 shot('08-legacy-completed');stop();launch();assert read_state()['money']==completed['money']
 logs=adb('logcat','-d','-s','godot','AndroidRuntime');(OUT/'logcat.txt').write_text(logs)
 assert 'SCRIPT ERROR:' not in logs and 'FATAL EXCEPTION' not in logs and adb('shell','pidof',PACKAGE).strip()
 report={'source_commit':source['source_commit'],'build_run':int(os.environ['BARISTA_BUILD_RUN']),'package':PACKAGE,'android':adb('shell','getprop','ro.build.version.release').strip(),'abi':adb('shell','getprop','ro.product.cpu.abi').strip(),'resolution':[width,height],'performance_five_guests':performance,'checks':['real touch','milk-first','brew refusal','miss/rework','free delivery','pending/collected restart','money/history','menu/background pause','isolated training','five guests','full300s shift','summary/next day','one paid perk','summary migration refund once','active legacy closing+payment+activation']}
 (OUT/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print('PASS: actual Android v2 full-cycle/touch/restart/legacy migration',flush=True)
finally:
 with (OUT/'logcat-all.txt').open('w') as f:subprocess.run(['adb','logcat','-d'],stdout=f,stderr=subprocess.STDOUT,check=False,timeout=30)
