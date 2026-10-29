extends RefCounted
const PERKS=["grind","brew","milk","grace","patience"]
const EVENTS=["calm","rush","milk","connoisseur"]
var data={}
func _init(unix_time: float,bias_minutes: int) -> void:
 data=make_day(day_key(unix_time,bias_minutes),bias_minutes)
static func make_day(key: String,bias: int) -> Dictionary:
 var rng=RandomNumberGenerator.new()
 rng.seed=key.hash()
 var choices=PERKS.duplicate()
 for i in range(choices.size()-1,0,-1):
  var j=rng.randi_range(0,i)
  var value=choices[i]
  choices[i]=choices[j]
  choices[j]=value
 return {"day_key":key,"zone_bias":bias,"mode":"SHOP","remaining":480.0,"success":false,"reward_collected":false,"offers":choices.slice(0,3),"perk":"","event":EVENTS[rng.randi_range(0,EVENTS.size()-1)]}
func select_perk(id: String) -> bool:
 if data.mode!="SHOP" or data.perk!="" or not id in data.offers: return false
 data.perk=id
 return true
static func day_key(unix_time: float,bias_minutes: int) -> String:
 return Time.get_date_string_from_unix_time(int(unix_time)+bias_minutes*60-28800)
func refresh(unix_time: float) -> Dictionary:
 var key=day_key(unix_time,int(data.zone_bias))
 if key<=data.day_key: return {}
 if data.mode in ["RUNNING","CLOSING"]: return {"action":"close"}
 if data.mode=="SUMMARY" and not data.reward_collected: return {}
 var bias=int(data.zone_bias)
 data=make_day(key,bias)
 return {"action":"new_day"}
func start() -> bool:
 if data.mode!="SHOP" or data.perk=="": return false
 data.mode="RUNNING"
 return true
func advance(seconds: float,unix_time: float,paused=false,order_started=false) -> Dictionary:
 if paused: return {}
 var change=refresh(unix_time)
 if data.mode!="RUNNING": return change
 data.remaining=maxf(0,data.remaining-maxf(0,seconds))
 if data.remaining==0 or change.get("action")=="close":
  data.mode="CLOSING"
  data.remaining=0
  return {"action":"close_started" if order_started else "close_unstarted"}
 return change
func finish(delivered: int,good: int) -> void:
 if data.mode!="CLOSING": return
 data.mode="SUMMARY"
 data.success=delivered>=10 and float(good)/maxi(1,delivered)>=0.8
func collect_reward() -> int:
 if data.mode!="SUMMARY" or data.reward_collected: return 0
 data.reward_collected=true
 data.mode="FINISHED"
 data.perk=""
 return 200 if data.success else 0
static func valid(s) -> bool:
 if not s is Dictionary or not s.get("offers") is Array or s.offers.size()!=3 or not s.get("event") in EVENTS: return false
 var seen={}
 for id in s.offers:
  if not id in PERKS or seen.has(id): return false
  seen[id]=true
 if s.get("perk")!="" and not s.get("perk") in s.offers: return false
 return s is Dictionary and s.get("day_key") is String and s.day_key.length()==10 and (s.get("zone_bias") is int or s.get("zone_bias") is float) and abs(s.zone_bias)<=840 and s.get("mode") in ["SHOP","RUNNING","CLOSING","SUMMARY","FINISHED"] and (s.get("remaining") is float or s.get("remaining") is int) and is_finite(s.remaining) and s.remaining>=0 and s.remaining<=480 and s.get("success") is bool and s.get("reward_collected") is bool
static func restore(snapshot_data: Dictionary):
 var shift=load("res://shift/shift.gd").new(0,0)
 shift.data=snapshot_data
 return shift
