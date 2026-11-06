extends RefCounted
# v2 domain session. Repository/UI stay on v1 until the migration task.
const Cup=preload("res://brewing/cup.gd")
const Evaluation=preload("res://brewing/evaluation.gd")
const Roster=preload("res://customers/roster.gd")
const Schema=preload("res://persistence/service_schema.gd")
const PRICES={"espresso":50,"cappuccino":80,"latte":90}
const BALANCE_VERSION="service-v2-start-1"
var data={"clock":0.0,"money":0,"next_id":2,"cup_id":1,"streak":0,"rng_state":"1","profiles":{},"visits":[],"payments":[]}
var cup= Cup.new()

func _init(seed_value=12345) -> void:
 var roster=Roster.new(seed_value)
 data.profiles=roster.profiles
 data.rng_state=roster.rng_state()
 for profile in data.profiles.values(): profile.trust_l=0.5

func allocate_id() -> int:
 var id=int(data.next_id)
 data.next_id=id+1
 return id

func find_visit(visit_id: int) -> Dictionary:
 for visit in data.visits:
  if visit.id==visit_id: return visit
 return {}

func spawn_visit(customer_id="",wish_recipe="") -> bool:
 if data.visits.size()>=5 or (wish_recipe!="" and not PRICES.has(wish_recipe)): return false
 var present=[]
 for visit in data.visits: present.append(visit.customer_id)
 if customer_id!="" and (not data.profiles.has(customer_id) or customer_id in present): return false
 var roster=Roster.new()
 roster.profiles=data.profiles
 roster.set_rng_state(data.rng_state)
 if customer_id=="": customer_id=roster.pick_available(present)
 if customer_id=="": return false
 if wish_recipe=="": wish_recipe=roster.pick_recipe(customer_id)
 data.rng_state=roster.rng_state()
 var budget=30+90*float(data.profiles[customer_id].trust_l)
 data.visits.append({"id":allocate_id(),"customer_id":customer_id,"wish_recipe":wish_recipe,"state":"WAITING","patience_budget":budget,"arrived_at":data.clock,"bubble_until":data.clock+3,"reaction_applied":false,"payment_id":0})
 return true

func remind_wish(visit_id: int) -> bool:
 var visit=find_visit(visit_id)
 if visit.is_empty() or visit.state!="WAITING" or data.clock>=visit.arrived_at+visit.patience_budget: return false
 visit.bubble_until=data.clock+3
 return true

func select_recipe(recipe: String) -> bool:
 return cup.select_recipe(recipe)

func tap(station: int) -> bool:
 return cup.tap(station,float(data.clock))

func take_cup() -> bool:
 return cup.take_cup()

func return_cup() -> bool:
 return cup.return_cup()

static func mood(j: float) -> String:
 if j>=90: return "delighted"
 if j>=75: return "happy"
 if j>=60: return "neutral"
 if j>=40: return "disappointed"
 if j>=20: return "very_unhappy"
 return "disgusted"

static func relationship_delta(result: Dictionary) -> int:
 # Author starting calibration: docs/plans/2026-11-05-v042-balance.md.
 var ideal=result.R==1 and result.g==1 and result.b==1 and result.T==1
 if result.contents!="espresso" or result.defects.has("milk"): ideal=ideal and result.m==1
 if ideal and result.J>=90: return 8
 if result.J>=75: return 5
 return -2 if result.J>=60 else -10

static func reaction(result: Dictionary) -> String:
 if result.R==0: return "Я же кофе просил!"
 if result.R<1: return "Я просил другой кофе"
 if result.T<1.0/3.0: return "Остыло"
 var strongest=0.0
 var description=""
 for defect in result.defects.values():
  if defect.severity>strongest:
   strongest=defect.severity
   description=defect.description
 if description!="": return description
 if result.W<=0.25: return "Долго ждал"
 return {"delighted":"Прекрасный кофе!","happy":"Вкусно!","neutral":"Нормально","disappointed":"Разочарован","very_unhappy":"Невкусно","disgusted":"Ужасно"}[mood(result.J)]

func deliver(cup_id: int,visit_id: int) -> bool:
 var visit=find_visit(visit_id)
 if cup_id!=data.cup_id or not cup.carrying or cup.is_empty() or visit.is_empty() or visit.state!="WAITING" or visit.reaction_applied: return false
 var waited=float(data.clock)-float(visit.arrived_at)
 if waited>=visit.patience_budget: return false
 var result=Evaluation.evaluate(cup.snapshot(),visit.wish_recipe,waited,visit.patience_budget,float(data.clock))
 if result.is_empty(): return false
 var profile=data.profiles[visit.customer_id]
 profile.trust_l=clampf(0.75*float(profile.trust_l)+0.25*result.C,0,1)
 profile.relationship=clampi(int(profile.relationship)+relationship_delta(result),-100,100)
 profile.mood=mood(result.J)
 profile.last_reaction=reaction(result)
 profile.visits+=1
 profile.history.append({"schema":2,"visit_id":visit.id,"cup_id":cup_id,"Q":result.Q,"J":result.J,"C":result.C,"T":result.T,"R":result.R,"balance_version":BALANCE_VERSION})
 if profile.history.size()>20: profile.history.pop_front()
 var good=result.J>=75
 data.streak=int(data.streak)+1 if good else 0
 var base=int(PRICES[visit.wish_recipe])
 var tip=0
 if good and (data.streak>=3 or profile.relationship>=30):
  tip=int(floor(base*(0.10+0.10*maxi(0,int(profile.relationship))/100.0)))
 var payment_id=allocate_id()
 data.payments.append({"id":payment_id,"visit_id":visit.id,"cup_id":cup_id,"base":base,"tip":tip,"combo":1,"amount":base+tip,"deadline":data.clock+12,"state":"PENDING"})
 visit.state="PAYMENT"
 visit.reaction_applied=true
 visit.evaluation=result
 visit.payment_id=payment_id
 cup=Cup.new(cup.recipe)
 data.cup_id=allocate_id()
 return true

func collect(payment_id: int) -> bool:
 for payment in data.payments:
  if payment.id!=payment_id: continue
  if payment.state!="PENDING" or data.clock>=payment.deadline: return false
  payment.state="COLLECTED"
  data.money=int(data.money)+int(payment.amount)
  var visit=find_visit(int(payment.visit_id))
  if not visit.is_empty(): visit.state="DEPARTING"
  return true
 return false

func advance(seconds: float,paused=false) -> void:
 if paused:
  cup.return_cup()
  return
 if not Cup.finite_number(seconds,0) or not Cup.finite_number(data.clock+seconds,0): return
 data.clock+=seconds
 for visit in data.visits:
  if visit.state!="WAITING" or data.clock<visit.arrived_at+visit.patience_budget: continue
  visit.state="DEPARTING"
  if not visit.reaction_applied:
   var profile=data.profiles[visit.customer_id]
   profile.relationship=maxi(-100,int(profile.relationship)-5)
   profile.mood="annoyed"
   profile.last_reaction="Не дождался"
   profile.visits+=1
   visit.reaction_applied=true
   data.streak=0
 for payment in data.payments:
  if payment.state!="PENDING" or data.clock<payment.deadline: continue
  payment.state="EXPIRED"
  var visit=find_visit(int(payment.visit_id))
  if not visit.is_empty(): visit.state="DEPARTING"

func finish_departure(visit_id: int) -> bool:
 var visit=find_visit(visit_id)
 if visit.is_empty() or visit.state!="DEPARTING": return false
 data.visits.erase(visit)
 # Monotonic IDs make old actions invalid without an unbounded tombstone list.
 for i in range(data.payments.size()-1,-1,-1):
  if data.payments[i].visit_id==visit_id: data.payments.remove_at(i)
 return true

func claim_legacy_reward() -> bool:
 if not data.has("legacy") or data.legacy.reward_claimed or data.legacy.reward_pending<=0:return false
 data.money=int(data.money)+int(data.legacy.reward_pending)
 data.legacy.reward_claimed=true
 return true

func snapshot() -> Dictionary:
 var result=data.duplicate(true)
 result.cup=cup.snapshot()
 return result

static func restore(snapshot_data: Dictionary):
 if not Schema.valid(snapshot_data): return null
 var s=load("res://orders/service.gd").new()
 s.data=snapshot_data.duplicate(true)
 s.cup=Cup.restore(s.data.cup)
 s.data.erase("cup")
 for key in ["money","next_id","cup_id","streak"]: s.data[key]=int(s.data[key])
 if s.data.has("upgrades"):
  for key in s.data.upgrades:s.data.upgrades[key]=int(s.data.upgrades[key])
 for profile in s.data.profiles.values():
  profile.visits=int(profile.visits)
  profile.relationship=int(profile.relationship)
 for visit in s.data.visits:
  visit.id=int(visit.id)
  visit.payment_id=int(visit.payment_id)
 for payment in s.data.payments:
  for key in ["id","visit_id","cup_id","base","tip","combo","amount"]: payment[key]=int(payment[key])
 return s
