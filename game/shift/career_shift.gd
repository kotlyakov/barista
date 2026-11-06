extends RefCounted
const Cup=preload("res://brewing/cup.gd")
const EVENTS=["calm","rain","regulars","festival","milk","critic"]
const STATS=["served","good","left","collected","expired","earned"]
static func make(day: int,event: String,last_summary=0) -> Dictionary:
 return {"day_number":day,"phase":"PREPARING","started_at":-1.0,"next_arrival_at":-1.0,"summary_id":0,"last_summary_id":last_summary,"event_id":event,"stats":{"served":0,"good":0,"left":0,"collected":0,"expired":0,"earned":0}}
static func arrival_base(day: int) -> float:
 return clampf(16/(1+0.12*(day-1)),6,16)
static func clock_minutes(shift: Dictionary,now: float) -> int:
 if shift.phase=="PREPARING":return 480
 if shift.phase in ["CLOSING","SUMMARY"]:return 1020
 return 480+int(floor(clampf((now-shift.started_at)/300,0,1)*540))
static func valid(s,clock: float,next_id: int,minimum=50,maximum=108,duration=12.0,allow_gifts=false) -> bool:
 if not s is Dictionary or s.size()!=8:return false
 if not Cup.whole(s.get("day_number"),1) or not s.get("phase") in ["PREPARING","RUNNING","CLOSING","SUMMARY"] or not s.get("event_id") in EVENTS:return false
 for key in ["summary_id","last_summary_id"]:
  if not Cup.whole(s.get(key)) or s[key]>=next_id:return false
 if s.day_number==1 and s.last_summary_id!=0:return false
 if s.day_number>1 and s.last_summary_id==0:return false
 if s.summary_id>0 and s.summary_id==s.last_summary_id:return false
 var stats_keys=STATS+(["gifted"] if allow_gifts else [])
 if not s.get("stats") is Dictionary or s.stats.size()!=stats_keys.size():return false
 for key in stats_keys:
  if not Cup.whole(s.stats.get(key)):return false
 if s.stats.good>s.stats.served or s.stats.collected+s.stats.expired>s.stats.served:return false
 var gifted=int(s.stats.get("gifted",0))
 if gifted>s.stats.collected:return false
 var paid=s.stats.collected-gifted
 if s.stats.earned<minimum*paid or s.stats.earned>maximum*paid:return false
 if not Cup.finite_number(s.get("started_at"),-1,clock) or not Cup.finite_number(s.get("next_arrival_at"),-1,clock+25):return false
 if s.phase=="PREPARING":
  if s.started_at!=-1 or s.next_arrival_at!=-1 or s.summary_id!=0:return false
  for key in stats_keys:
   if s.stats[key]!=0:return false
  return true
 if s.started_at<0 or s.next_arrival_at<s.started_at:return false
 if s.phase=="RUNNING":return s.summary_id==0 and clock<s.started_at+300
 if clock<s.started_at+300 or clock>s.started_at+315+duration:return false
 return (s.summary_id==next_id-1 and s.summary_id>s.last_summary_id) if s.phase=="SUMMARY" else s.summary_id==0
