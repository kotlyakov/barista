extends RefCounted
# v2 domain session. Repository/UI stay on v1 until the migration task.
const Cup=preload("res://brewing/cup.gd")
const Evaluation=preload("res://brewing/evaluation.gd")
const Roster=preload("res://customers/roster.gd")
const Schema=preload("res://persistence/service_schema.gd")
const Career=preload("res://economy/career.gd")
const CareerShift=preload("res://shift/career_shift.gd")
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

func draw_forecast(day: int) -> String:
 var rng=RandomNumberGenerator.new();rng.state=int(data.rng_state)
 var choices=["calm","rain","regulars"] if day%2==1 else ["festival","milk","critic"]
 var event=choices[rng.randi_range(0,choices.size()-1)]
 data.rng_state=str(rng.state)
 return event

func enable_career() -> bool:
 if data.has("shift") or data.has("legacy") or not data.visits.is_empty() or not data.payments.is_empty() or not cup.is_empty():return false
 data.shift=CareerShift.make(1,draw_forecast(1))
 return true

func enable_development() -> bool:
 if not data.has("shift") or data.shift.phase!="PREPARING" or data.has("economy") or data.has("legacy") or data.has("career"):return false
 if not data.has("upgrades"):data.upgrades={"grind":0,"brew":0,"milk":0,"ads":0,"tuning":0,"grace":0}
 if data.upgrades.tuning!=0 or data.upgrades.grace!=0:return false
 data.economy=Career.make();data.shift.stats.gifted=0;Career.offers(self);configure_cup()
 return true

func shop_open() -> bool:
 return data.has("economy") and data.shift.phase=="PREPARING"

func enable_auto_recipe() -> bool:
 if not data.has("economy") or data.has("auto_recipe"):return false
 data.auto_recipe=true
 if cup.is_empty():reset_cup()
 return true

func reset_cup() -> void:
 if data.get("auto_recipe",false):
  cup=Cup.new("espresso")
  cup.milk_doses=0
 else:cup=Cup.new(cup.recipe)
 configure_cup()

func configure_cup() -> void:
 if not data.has("economy"):return
 cup.select_recipe(cup.recipe,Career.targets(data,cup.recipe))
 cup.cooling_seconds=Career.effects(data).heat

func buy_perk(perk: String,day: int) -> bool:
 if not shop_open() or day!=data.shift.day_number or data.economy.choice!="" or not perk in data.economy.offers:return false
 var price=Career.purchase_price(data,int(Career.PERKS[perk].price))
 if data.money<price:return false
 data.money-=price;data.economy.choice=perk;configure_cup();return true

func skip_perk(day: int) -> bool:
 if not shop_open() or day!=data.shift.day_number or data.economy.choice!="":return false
 data.economy.choice="skip";return true

func buy_equipment(station: String,level: int) -> bool:
 if not shop_open() or not station in ["grind","brew","milk","ads"] or level<0 or level>=Career.EQUIPMENT_PRICES.size() or data.upgrades[station]!=level:return false
 var price=Career.equipment_price(data,level)
 if data.money<price:return false
 data.money-=price;data.upgrades[station]=level+1;configure_cup();return true

func buy_passive(id: String,level: int) -> bool:
 if not shop_open() or not id in Career.PASSIVE_IDS or level<0 or level>=Career.PASSIVE_PRICES.size() or Career.passive_level(data,id)!=level:return false
 var price=Career.purchase_price(data,int(Career.PASSIVE_PRICES[level]))
 if data.money<price:return false
 var levels: Dictionary=data.economy.get("passives",{})
 levels[id]=level+1
 data.economy.passives=levels
 data.money-=price
 configure_cup()
 return true

func buy_module(module: String) -> bool:
 if not shop_open() or not module in Career.MODULES or module in data.economy.owned_modules:return false
 var price=Career.purchase_price(data,int(Career.MODULES[module].price))
 if data.money<price:return false
 data.money-=price;data.economy.owned_modules.append(module);return true

func equip_module(module: String,slot: int) -> bool:
 if not shop_open() or slot<0 or slot>1 or not module in data.economy.owned_modules or module in data.economy.equipped_modules:return false
 data.economy.equipped_modules[slot]=module;configure_cup();return true

func remove_module(slot: int) -> bool:
 if not shop_open() or slot<0 or slot>1 or data.economy.equipped_modules[slot]=="":return false
 data.economy.equipped_modules[slot]="";configure_cup();return true

func reserve_gift(customer: String) -> bool:
 if not shop_open() or not data.profiles.has(customer) or data.economy.gifts[customer]:return false
 var price=Career.purchase_price(data,int(PRICES[data.profiles[customer].favorite]))
 if data.money<price:return false
 data.money-=price;data.economy.gifts[customer]=true;return true

func claim_goal(customer: String,tier: int) -> bool:
 if not shop_open() or not data.profiles.has(customer) or tier<0 or tier>=2 or data.economy.claimed[customer]!=tier or data.economy.goals[customer]<Career.GOAL_TARGETS[tier]:return false
 data.money+=Career.GOAL_REWARDS[tier];data.economy.claimed[customer]=tier+1;return true

func promote_league(level: int) -> bool:
 if not shop_open() or level<0 or level>=2 or data.economy.league!=level or data.economy.fame<Career.LEAGUE_FAME[level+1]:return false
 data.economy.league=level+1;return true

func start_shift(expected_day: int) -> bool:
 if not data.has("shift") or data.shift.phase!="PREPARING" or data.shift.day_number!=expected_day:return false
 if data.has("economy"):
  var cost=int(Career.effects(data).maintenance)
  if data.money<cost:return false
  data.money-=cost
  if data.economy.choice=="":data.economy.choice="skip"
  data.economy.active_perk="" if data.economy.choice=="skip" else data.economy.choice
  if expected_day>=6:data.shift.market_rules=1
 data.shift.phase="RUNNING";data.shift.started_at=data.clock;data.shift.next_arrival_at=data.clock
 configure_cup()
 spawn_visit();schedule_arrival()
 return true

func finish_summary(summary_id: int) -> bool:
 if not data.has("shift") or data.shift.phase!="SUMMARY" or summary_id!=data.shift.summary_id:return false
 var day=int(data.shift.day_number)+1
 data.shift=CareerShift.make(day,draw_forecast(day),summary_id)
 reset_cup();data.cup_id=allocate_id()
 if data.has("economy"):
  data.shift.stats.gifted=0
  data.economy.choice="";data.economy.active_perk="";data.economy.critic_spawned=false
  Career.offers(self);configure_cup()
 return true

func clock_minutes() -> int:
 return CareerShift.clock_minutes(data.shift,data.clock) if data.has("shift") else 480

func can_prepare() -> bool:
 if not data.has("shift"):return true
 if data.shift.phase=="RUNNING":return true
 if data.shift.phase=="CLOSING" and data.clock<data.shift.started_at+315:
  for visit in data.visits:
   if visit.state=="WAITING" and data.clock<visit.arrived_at+visit.patience_budget:return true
 return false

func schedule_arrival() -> void:
 var rng=RandomNumberGenerator.new();rng.state=int(data.rng_state)
 var base=CareerShift.arrival_base(int(data.shift.day_number))
 if data.has("economy"):base=Career.arrival_interval(data,float(data.clock)-float(data.shift.started_at))
 data.shift.next_arrival_at=data.clock+rng.randf_range(0.75*base,1.25*base)
 data.rng_state=str(rng.state)

func spawn_visit(customer_id="",wish_recipe="") -> bool:
 if data.has("shift") and data.shift.phase!="RUNNING":return false
 if data.visits.size()>=5 or (wish_recipe!="" and not PRICES.has(wish_recipe)): return false
 var present=[]
 for visit in data.visits: present.append(visit.customer_id)
 if customer_id!="" and (not data.profiles.has(customer_id) or customer_id in present): return false
 var roster=Roster.new()
 roster.profiles=data.profiles
 roster.set_rng_state(data.rng_state)
 if customer_id=="": customer_id=roster.pick_available(present)
 if customer_id=="": return false
 if wish_recipe=="": wish_recipe=roster.pick_recipe(customer_id,2.0 if data.has("economy") and data.shift.event_id=="milk" else 1.0,4.0 if data.has("economy") and data.shift.event_id=="regulars" else 2.0)
 data.rng_state=roster.rng_state()
 var budget=(30+90*float(data.profiles[customer_id].trust_l))*Career.patience_factor(data)
 if data.get("shift",{}).get("market_rules",0)==1 and Career.in_rush(int(data.shift.day_number),float(data.clock)-float(data.shift.started_at)):
  budget=maxf(18.0,budget*(1.0-.07*Career.market_step(int(data.shift.day_number))))
 data.visits.append({"id":allocate_id(),"customer_id":customer_id,"wish_recipe":wish_recipe,"state":"WAITING","patience_budget":budget,"arrived_at":data.clock,"bubble_until":data.clock+Career.wish_seconds(data),"wish_shown_at":-1.0,"reaction_applied":false,"payment_id":0})
 if data.has("economy"):
  var visit=data.visits.back()
  visit.gift=data.economy.gifts[customer_id];data.economy.gifts[customer_id]=false
  visit.critic=data.shift.event_id=="critic" and not data.economy.critic_spawned
  if visit.critic:data.economy.critic_spawned=true
 return true

func remind_wish(visit_id: int) -> bool:
 var visit=find_visit(visit_id)
 if visit.is_empty() or visit.state!="WAITING" or data.clock>=visit.arrived_at+visit.patience_budget: return false
 if visit.has("wish_shown_at") and visit.wish_shown_at<0:visit.wish_shown_at=data.clock
 visit.bubble_until=data.clock+Career.wish_seconds(data)
 return true

func show_arrival_wish(visit_id: int) -> bool:
 var visit=find_visit(visit_id)
 if visit.is_empty() or not visit.has("wish_shown_at") or visit.wish_shown_at>=0:return false
 return remind_wish(visit_id)

func select_recipe(recipe: String) -> bool:
 if data.get("auto_recipe",false):return false
 if data.has("shift") and data.shift.phase!="PREPARING" and not can_prepare():return false
 if data.has("economy"):
  var selected=cup.select_recipe(recipe,Career.targets(data,recipe)) if Cup.TARGETS.has(recipe) else false
  if selected:cup.cooling_seconds=Career.effects(data).heat
  return selected
 return cup.select_recipe(recipe)

func tap(station: int) -> bool:
 if not can_prepare():return false
 return cup.tap(station,float(data.clock))

func add_milk() -> bool:
 if not can_prepare() or cup.milk_doses<0 or cup.milk_doses>=2:return false
 var recipe_id: String=Cup.DOSE_RECIPES[cup.milk_doses+1]
 var targets=Career.targets(data,recipe_id)
 return cup.add_milk(float(data.clock),int(targets[2]))

func discard_cup() -> bool:
 if not can_prepare() or cup.is_empty() or cup.carrying:return false
 reset_cup()
 data.cup_id=allocate_id()
 return true

func take_cup() -> bool:
 if not can_prepare():return false
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
 if not can_prepare():return false
 var visit=find_visit(visit_id)
 if cup_id!=data.cup_id or not cup.carrying or cup.is_empty() or visit.is_empty() or visit.state!="WAITING" or visit.reaction_applied: return false
 var waited=float(data.clock)-float(visit.arrived_at)
 if waited>=visit.patience_budget: return false
 var result=Evaluation.evaluate(cup.snapshot(),visit.wish_recipe,waited,visit.patience_budget,float(data.clock))
 if result.is_empty(): return false
 var profile=data.profiles[visit.customer_id]
 profile.trust_l=clampf(0.75*float(profile.trust_l)+0.25*result.C,0,1)
 var delta=relationship_delta(result)
 if delta>0:delta+=Career.passive_level(data,"relationship")
 profile.relationship=clampi(int(profile.relationship)+delta,-100,100)
 profile.mood=mood(result.J)
 profile.last_reaction=reaction(result)
 profile.visits+=1
 profile.history.append({"schema":2,"visit_id":visit.id,"cup_id":cup_id,"Q":result.Q,"J":result.J,"C":result.C,"T":result.T,"R":result.R,"balance_version":BALANCE_VERSION})
 if profile.history.size()>20: profile.history.pop_front()
 var good=result.J>=75
 if data.has("shift"):
  data.shift.stats.served+=1
  if good:data.shift.stats.good+=1
 data.streak=int(data.streak)+1 if good else 0
 if data.has("economy") and good:
  data.economy.fame+=1+Career.passive_level(data,"fame")+(5 if visit.get("critic",false) and result.J>=90 else 0)
  if visit.wish_recipe==profile.favorite and result.R==1:data.economy.goals[visit.customer_id]=mini(6,int(data.economy.goals[visit.customer_id])+1)
 var gift=visit.get("gift",false)
 var base=0 if gift else Career.base_price(data,visit.wish_recipe,visit.get("critic",false))
 var wrong=result.R<1.0 and not gift
 if wrong:base=Career.substitute_price(base,result)
 var refused=wrong and base==0
 var tip=0
 if not gift and not wrong and good and (data.streak>=3 or profile.relationship>=30):
  tip=Career.tip_amount(data,base,int(profile.relationship))
 var payment_id=allocate_id()
 var receipt={"id":payment_id,"visit_id":visit.id,"cup_id":cup_id,"base":base,"tip":tip,"combo":1,"amount":base+tip,"deadline":data.clock+Career.effects(data).coins,"state":"PENDING"}
 if wrong:
  receipt.discounted=true
  profile.last_reaction += " За это не плачу." if refused else " Заплачу половину."
 if gift:receipt.state="COLLECTED"
 elif refused:receipt.state="REFUSED"
 data.payments.append(receipt)
 visit.state="DEPARTING" if gift or refused else "PAYMENT"
 if refused and data.has("shift"):
  data.shift.stats.refused=int(data.shift.stats.get("refused",0))+1
 if gift and data.has("shift"):
  data.shift.stats.collected+=1;data.shift.stats.gifted+=1
 visit.reaction_applied=true
 visit.evaluation=result
 visit.reaction_until=data.clock+3
 visit.payment_id=payment_id
 reset_cup()
 data.cup_id=allocate_id()
 process_shift_due()
 return true

func collect(payment_id: int) -> bool:
 for payment in data.payments:
  if payment.id!=payment_id: continue
  if payment.state!="PENDING" or data.clock>=payment.deadline: return false
  payment.state="COLLECTED"
  data.money=int(data.money)+int(payment.amount)
  if data.has("shift"):
   data.shift.stats.collected+=1;data.shift.stats.earned+=int(payment.amount)
  var visit=find_visit(int(payment.visit_id))
  if not visit.is_empty(): visit.state="DEPARTING"
  process_shift_due()
  return true
 return false

func advance(seconds: float,paused=false) -> void:
 if paused:
  cup.return_cup()
  return
 if not Cup.finite_number(seconds,0) or not Cup.finite_number(data.clock+seconds,0): return
 if not data.has("shift"):
  advance_visits_to(data.clock+seconds)
  return
 if not data.shift.phase in ["RUNNING","CLOSING"]:return
 var target=float(data.clock)+seconds
 process_shift_due()
 while data.clock<target and data.shift.phase in ["RUNNING","CLOSING"]:
  var boundary=target
  if data.shift.phase=="RUNNING":
   boundary=minf(boundary,data.shift.started_at+300)
   if data.visits.size()<5:boundary=minf(boundary,data.shift.next_arrival_at)
  elif data.clock<data.shift.started_at+315:boundary=minf(boundary,data.shift.started_at+315)
  for visit in data.visits:
   if visit.state=="WAITING":boundary=minf(boundary,visit.arrived_at+visit.patience_budget)
  for payment in data.payments:
   if payment.state=="PENDING":boundary=minf(boundary,payment.deadline)
  advance_visits_to(boundary)
  process_shift_due()

func leave_visit(visit: Dictionary) -> void:
 visit.state="DEPARTING"
 if visit.reaction_applied:return
 var profile=data.profiles[visit.customer_id]
 profile.relationship=maxi(-100,int(profile.relationship)-5)
 profile.mood="annoyed";profile.last_reaction="Не дождался";profile.visits+=1
 visit.reaction_applied=true;data.streak=0
 if data.has("shift"):data.shift.stats.left+=1

func advance_visits_to(now: float) -> void:
 data.clock=now
 for visit in data.visits:
  if visit.state!="WAITING" or data.clock<visit.arrived_at+visit.patience_budget: continue
  leave_visit(visit)
 for payment in data.payments:
  if payment.state!="PENDING" or data.clock<payment.deadline: continue
  payment.state="EXPIRED"
  if data.has("shift"):data.shift.stats.expired+=1
  var visit=find_visit(int(payment.visit_id))
  if not visit.is_empty(): visit.state="DEPARTING"

func process_shift_due() -> void:
 if not data.has("shift"):return
 var shift=data.shift
 # Close the door before handling any arrival scheduled at exactly17:00.
 if shift.phase=="RUNNING" and data.clock>=shift.started_at+300:shift.phase="CLOSING"
 if shift.phase=="CLOSING":
  if data.clock>=shift.started_at+315:
   for visit in data.visits:
    if visit.state=="WAITING":leave_visit(visit)
  var waiting=false
  for visit in data.visits:
   if visit.state=="WAITING":waiting=true
  if not waiting:cup.return_cup()
  if waiting:return
  for payment in data.payments:
   if payment.state=="PENDING":return
  shift.phase="SUMMARY";shift.summary_id=allocate_id()
  cup.return_cup();data.visits.clear();data.payments.clear()
 elif shift.phase=="RUNNING" and shift.next_arrival_at<=data.clock and data.visits.size()<5:
  if spawn_visit():schedule_arrival()

func finish_departure(visit_id: int) -> bool:
 var visit=find_visit(visit_id)
 if visit.is_empty() or visit.state!="DEPARTING": return false
 data.visits.erase(visit)
 # Monotonic IDs make old actions invalid without an unbounded tombstone list.
 for i in range(data.payments.size()-1,-1,-1):
  if data.payments[i].visit_id==visit_id: data.payments.remove_at(i)
 process_shift_due()
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
 if s.data.has("shift"):
  for key in ["day_number","summary_id","last_summary_id"]:s.data.shift[key]=int(s.data.shift[key])
  for key in s.data.shift.stats:s.data.shift.stats[key]=int(s.data.shift.stats[key])
 if s.data.has("economy"):
  for key in ["version","fame","league"]:s.data.economy[key]=int(s.data.economy[key])
  for field in ["goals","claimed","passives"]:
   for key in s.data.economy.get(field,{}):s.data.economy[field][key]=int(s.data.economy[field][key])
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
