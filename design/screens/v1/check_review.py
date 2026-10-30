"""Small reproducible integrity check for the offline owner-review package."""
import base64, hashlib, json, re, struct, subprocess, tempfile, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
page=(ROOT/'design/screens/v1/review.html').read_text()
def field(name):
 return json.JSONDecoder().raw_decode(page.split(name+'=',1)[1])[0]
images=field('IMAGES');links=field('LINKS');sounds=field('AUDIO');events=field('EVENTS')
assert len(images)==15 and len(events)==11
for key,items in links.items():
 assert key in images
 for item in items:
  assert item['target'] in images,item
  assert 0<=item['x']<item['x']+item['w']<=1600
  assert 0<=item['y']<item['y']+item['h']<=900
for key,data in images.items():
 assert base64.b64decode(data)==(ROOT/f'design/screens/v1/{key}.png').read_bytes()
for e in events:
 p=ROOT/'audio/candidates/v1'/e['file']
 assert base64.b64decode(sounds[e['id']])==p.read_bytes()
 with wave.open(str(p)) as w:
  assert w.getparams()[:3]==(1,2,24000)
  assert abs(w.getnframes()/w.getframerate()-e['duration'])<.0001
  data=w.readframes(w.getnframes());values=struct.unpack('<'+'h'*(len(data)//2),data)
  assert 0<max(map(abs,values))<32767
script=re.search(r'<script>(.*?)</script>',page,re.S).group(1)
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)/'review.js';p.write_text(script);subprocess.run(['node','--check',str(p)],check=True)
registry=json.loads((ROOT/'approvals/REGISTRY.json').read_text())
count=0
for e in registry['entries']:
 if e['status']=='PRESENTED' and e.get('presented_at')=='2026-10-30':
  for name in e['artifact_paths']:
   assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==e['sha256'][name],name
   count+=1
print(f'PASS: {len(images)} screens, all hotspot targets/bounds, {len(events)} embedded PCM samples, JS syntax, {count} immutable snapshot hashes.')
print('Browser click-through, human listening, game/Android runtime: NOT_RUN.')
