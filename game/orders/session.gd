extends RefCounted
const Brew=preload("res://brewing/brew.gd")
const Shift=preload("res://shift/shift.gd")
const Roster=preload("res://customers/roster.gd")
const UPGRADES={"grind":3,"brew":3,"milk":3,"tuning":3,"grace":2,"ads":3}
const UPGRADE_PRICES=[400,800,1400]
const DEFAULT_PREFERENCES={"master":0.8,"music":0.5,"effects":0.8,"vibration":true,"tutorial_seen":false,"muted":false}
const PRICES={"espresso":50,"cappuccino":80,"latte":90}
var data={"clock":0.0,"money":0,"next_id":1,"streak":0,"rng_state":"1","profiles":{},"order":{}}
var brew
var shift
# Empty in production until real-phone calibration (TASK-022).
var speed_thresholds={}
func _init() -> void:
 data.preferences=DEFAULT_PREFERENCES.duplicate()
 data.upgrades={"grind":0,"brew":0,"milk":0,"tuning":0,"grace":0,"ads":0}
 data.profiles=Roster.defaults()
 var roster=Roster.new(12345)
 data.rng_state=roster.rng_state()
 next_order("cappuccino","guest-01")
func next_order(recipe="",customer_id="") -> bool:
 if shift!=null and shift.data.mode!="RUNNING": return false
 if data.order.get("arrival_remaining",0)>0: return false
 if not data.order.is_empty() and not data.order.state in ["COLLECTED","LEFT","UNPAID"]: return false
 if recipe!="" and not PRICES.has(recipe): return false
 if customer_id!="" and not data.profiles.has(customer_id): return false
 var roster=Roster.new()
 roster.profiles=data.profiles
 roster.set_rng_state(data.rng_state)
 if customer_id=="": customer_id=roster.pick()
 if recipe=="": recipe=roster.pick_recipe(customer_id,1.5 if shift!=null and shift.data.event=="milk" else 1.0)
 data.rng_state=roster.rng_state()
 var targets=Brew.TARGETS[recipe].duplicate()
 var reductions=[int(data.upgrades.grind),int(data.upgrades.brew),int(data.upgrades.milk)]
 var perk=shift.data.perk if shift!=null else ""
 for i in range(3):
  if perk==["grind","brew","milk"][i]: reductions[i]+=2
 for i in range(targets.size()): targets[i]=maxi(1,int(targets[i])-int(reductions[i]))
 brew=Brew.new(recipe,targets,int(data.upgrades.grace)+(1 if perk=="grace" else 0),pow(0.9,int(data.upgrades.tuning)))
 var id=int(data.next_id)
 data.next_id=id+1
 data.order={"id":id,"customer_id":customer_id,"recipe":recipe,"state":"BREWING","first_tap":-1.0,"patience":35.0*(1.25 if perk=="patience" else 1.0)*(1.2 if shift!=null and shift.data.event=="calm" else 1.0),"late":false,"payment":{},"reaction_applied":false}
 return true
func enable_shift(unix_time: float,bias_minutes: int) -> void:
 shift=Shift.new(unix_time,bias_minutes)
 data.shift=shift.data
 data.stats={"delivered":0,"good":0}
 data.order.state="DORMANT"
func arrival_delay() -> float:
 return maxf(1.0,3.0*pow(0.9,int(data.upgrades.ads))*(0.75 if shift!=null and shift.data.event=="rush" else 1.0))
func choose_perk(id: String) -> bool:
 return shift!=null and shift.select_perk(id)
func purchase(upgrade_id: String,expected_level: int) -> bool:
 if shift==null or shift.data.mode!="SHOP" or not UPGRADES.has(upgrade_id): return false
 var level=int(data.upgrades[upgrade_id])
 if level!=expected_level or level>=UPGRADES[upgrade_id] or data.money<UPGRADE_PRICES[level]: return false
 data.money-=UPGRADE_PRICES[level]
 data.upgrades[upgrade_id]=level+1
 return true
func start_shift() -> bool:
 if shift==null or not shift.start(): return false
 data.stats={"delivered":0,"good":0}
 data.order.state="LEFT"
 data.order.erase("arrival_remaining")
 return next_order()
func collect_reward() -> bool:
 if shift==null or shift.data.mode!="SUMMARY" or shift.data.reward_collected: return false
 data.money+=shift.collect_reward()
 return true
func advance(seconds: float,paused=false,unix_time=-1.0) -> void:
 if paused or seconds<0 or not is_finite(seconds): return
 if shift!=null:
  var wall=Time.get_unix_time_from_system() if unix_time<0 else unix_time
  var transition=shift.advance(seconds,wall,false,data.order.state=="BREWING" and data.order.first_tap>=0)
  data.shift=shift.data
  if transition.get("action")=="close_unstarted" and data.order.state=="BREWING" and data.order.first_tap<0: data.order.state="CLOSED"
  if shift.data.mode=="CLOSING" and not data.order.state in ["BREWING","PAYMENT"]: shift.finish(data.stats.delivered,data.stats.good)
  if not shift.data.mode in ["RUNNING","CLOSING"]: return
 data.clock+=seconds
 if data.order.has("arrival_remaining"): data.order.arrival_remaining=maxf(0,data.order.arrival_remaining-seconds)
 if data.order.state=="BREWING":
  data.order.patience=maxf(0,data.order.patience-seconds)
  if data.order.patience==0:
   data.order.late=true
   if data.order.first_tap<0:
    data.order.state="LEFT"
    data.order.arrival_remaining=arrival_delay()
    data.streak=0
    react("annoyed","Не дождался",-5)
 elif data.order.state=="PAYMENT" and data.clock>=data.order.payment.deadline:
  data.order.state="UNPAID"
  data.order.arrival_remaining=arrival_delay()
func tap(station: int) -> bool:
 if shift!=null and not shift.data.mode in ["RUNNING","CLOSING"]: return false
 if data.order.state!="BREWING" or (data.order.first_tap<0 and data.order.patience<=0): return false
 if not brew.tap(station): return false
 if data.order.first_tap<0: data.order.first_tap=data.clock
 return true
func take_cup() -> bool:
 return data.order.state=="BREWING" and brew.take_cup()
func deliver(cup_id: int,customer_id: String) -> bool:
 var order=data.order
 if order.state!="BREWING" or not brew.locked or cup_id!=int(order.id) or customer_id!=order.customer_id: return false
 var quality=brew.quality()
 order.state="PAYMENT"
 order.quality=quality
 if data.has("stats"):
  data.stats.delivered+=1
  if quality>=0.8: data.stats.good+=1
 order.quality_by_stage=brew.qualities()
 order.defects=brew.defects()
 var mood="annoyed" if order.late or quality<0.5 else "happy" if quality>=0.8 else "neutral"
 var reaction="Опоздал" if order.late else "Вкусно!" if quality>=0.8 else "Обычно" if quality>=0.5 else "Невкусно"
 if not order.late:
  var strongest=0.0
  for defect in Brew.DEFECTS:
   var severity=float(order.defects.get(defect,0))
   if severity>strongest:
    strongest=severity
    reaction={"grind_bitter":"Горчит", "brew_astringent":"Вяжет", "milk_overheated":"Перегрето"}[defect]
 react(mood,reaction,8 if quality==1 else 5 if quality>=0.8 else -2 if quality>=0.5 else -10)
 var base=int(PRICES[order.recipe])
 var good=quality>=0.8 and not order.late
 data.streak=int(data.streak)+1 if good else 0
 var relation=int(data.profiles[order.customer_id].relationship)
 var tip=int(floor(base*(0.10+0.10*maxi(relation,0)/100.0)*(1.25 if shift!=null and shift.data.event=="connoisseur" else 1.0))) if good and (data.streak>=3 or relation>=30) else 0
 var combo=1
 if speed_thresholds.has(order.recipe) and quality==1.0 and not order.late and data.clock-order.first_tap<=speed_thresholds[order.recipe]: combo=2
 order.payment={"id":int(order.id),"base":base,"tip":tip,"combo":combo,"amount":base*combo+tip,"collected":false,"deadline":data.clock+12.0}
 return true
func react(mood: String,reaction: String,relationship_delta: int) -> void:
 if data.order.reaction_applied: return
 var profile=data.profiles[data.order.customer_id]
 profile.mood=mood
 profile.last_reaction=reaction
 profile.relationship=clampi(int(profile.relationship)+relationship_delta,-100,100)
 profile.visits+=1
 profile.history.append({"quality":data.order.get("quality",-1),"late":data.order.late})
 if profile.history.size()>20: profile.history.pop_front()
 data.order.reaction_applied=true
func collect(payment_id: int) -> bool:
 var order=data.order
 if order.state!="PAYMENT" or data.clock>=order.payment.deadline or order.payment.collected or int(order.payment.id)!=payment_id: return false
 data.money+=int(order.payment.amount)
 order.payment.collected=true
 order.state="COLLECTED"
 order.arrival_remaining=arrival_delay()
 return true
static func valid_preference(key: String,value) -> bool:
 if not DEFAULT_PREFERENCES.has(key): return false
 if key in ["vibration","tutorial_seen","muted"]: return value is bool
 return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1
func set_preference(key: String,value) -> bool:
 if not valid_preference(key,value): return false
 data.preferences[key]=value
 return true
func snapshot() -> Dictionary:
 var result=data.duplicate(true)
 result.brew=brew.snapshot()
 return result
static func restore(snapshot_data: Dictionary):
 var g=load("res://orders/session.gd").new()
 g.data=snapshot_data.duplicate(true)
 if not g.data.has("preferences"): g.data.preferences=DEFAULT_PREFERENCES.duplicate()
 if not g.data.preferences.has("muted"): g.data.preferences.muted=false
 for key in ["money","next_id","streak"]: g.data[key]=int(g.data[key])
 for profile in g.data.profiles.values():
  profile.relationship=int(profile.relationship)
  profile.visits=int(profile.visits)
 for id in g.data.upgrades: g.data.upgrades[id]=int(g.data.upgrades[id])
 g.data.order.id=int(g.data.order.id)
 for key in ["id","amount","base","tip","combo"]:
  if g.data.order.payment.has(key): g.data.order.payment[key]=int(g.data.order.payment[key])
 if g.data.has("stats"):
  g.data.stats.delivered=int(g.data.stats.delivered)
  g.data.stats.good=int(g.data.stats.good)
 if g.data.has("shift"): g.data.shift.zone_bias=int(g.data.shift.zone_bias)
 g.brew=Brew.restore(g.data.brew)
 g.data.erase("brew")
 if g.data.has("shift"): g.shift=Shift.restore(g.data.shift)
 return g
