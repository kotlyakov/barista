extends RefCounted
const Cup=preload("res://brewing/cup.gd")
const Candidate=preload("res://persistence/legacy_candidate.gd")
const LegacyStore=preload("res://persistence/store.gd")
const Career=preload("res://economy/career.gd")
const CareerShift=preload("res://shift/career_shift.gd")
const PRICES={"espresso":50,"cappuccino":80,"latte":90}
const MOODS=["neutral","happy","annoyed","delighted","disappointed","very_unhappy","disgusted"]
const REQUIRED=["clock","money","next_id","cup_id","streak","rng_state","profiles","visits","payments","cup"]
const OPTIONAL=["preferences","upgrades","legacy","career","shift","economy","migration","auto_recipe"]
static func number(v,lo=0.0,hi=1.0e12) -> bool:
 return Cup.finite_number(v,lo,hi)
static func integer(v,lo=0,hi=2147483647) -> bool:
 return number(v,lo,hi) and float(v)==floor(float(v))
static func text(v,limit=300) -> bool:
 return v is String and v.length()<=limit
static func id(v,s) -> bool:
 return integer(v,1,int(s.next_id)-1)
static func score(e) -> bool:
 if not e is Dictionary:return false
 for key in ["g","b","m","Q","d","T","W","R","C"]:
  if not number(e.get(key),0,1):return false
 if not number(e.get("J"),0,100) or (e.R!=0 and e.R!=0.5 and e.R!=1):return false
 if not e.get("contents") in ["espresso","cappuccino","latte","coffee_milk","milk","grounds","milk_grounds"]:return false
 var factor=(0.20+0.80*e.R)*(0.25+0.75*e.T)*(0.40+0.60*e.d)
 if absf(e.C-e.Q*factor)>0.000001 or absf(e.J-100*(0.85*e.Q+0.15*e.W)*factor)>0.000001:return false
 if not e.get("defects") is Dictionary or e.defects.size()>3:return false
 for key in e.defects:
  var d=e.defects[key]
  if not key in ["grind","brew","milk"] or not d is Dictionary:return false
  if not d.get("kind") in ["missing","under","over"] or not integer(d.get("level"),0,10) or not number(d.get("severity"),0,1) or not text(d.get("description")):return false
 return true
static func valid(s) -> bool:
 if not s is Dictionary:return false
 for key in REQUIRED:
  if not s.has(key):return false
 for key in s:
  if not key in REQUIRED and not key in OPTIONAL:return false
 if not number(s.clock) or not integer(s.money) or not integer(s.next_id,2) or not integer(s.streak) or not id(s.cup_id,s):return false
 if not s.rng_state is String or not s.rng_state.is_valid_int():return false
 var digits=s.rng_state.trim_prefix("-")
 var limit="9223372036854775808" if s.rng_state.begins_with("-") else "9223372036854775807"
 if digits.length()>19 or (digits.length()==19 and digits>limit) or str(int(s.rng_state))!=s.rng_state:return false
 if not Cup.valid(s.cup) or s.cup.last_tap>s.clock:return false
 if s.has("auto_recipe") and (not s.auto_recipe is bool or not s.auto_recipe or not s.has("economy")):return false
 if s.cup.has("milk_doses") and not s.has("auto_recipe"):return false
 if s.has("auto_recipe") and s.cup.first_tap<0 and not s.cup.has("milk_doses"):return false
 if not s.profiles is Dictionary or s.profiles.size()!=6 or not s.visits is Array or s.visits.size()>5 or not s.payments is Array or s.payments.size()>5:return false
 var old={}
 if s.has("migration"):
  if s.has("legacy") or not Candidate.valid_receipt(s.migration) or not s.has("economy") or not s.has("preferences"):return false
  old=s.migration.source_snapshot
 if s.has("legacy"):
  if not s.legacy is Dictionary or s.legacy.get("review_only")!=true or not LegacyStore.valid(s.legacy.get("source_snapshot")):return false
  old=s.legacy.source_snapshot
  if not text(s.legacy.get("source_hash"),64) or s.legacy.source_hash.length()!=64 or not s.legacy.source_hash.is_valid_hex_number(false):return false
  if not s.legacy.get("reward_claimed") is bool or not integer(s.legacy.get("reward_pending"),0,200):return false
  if not s.legacy.get("temperature_policy") in ["COLD_REVIEW"]:return false
  if s.legacy.source_hash!=JSON.stringify(old).sha256_text():return false
  var old_shift=old.get("shift",{})
  var earned=200 if old_shift.get("mode")=="SUMMARY" and old_shift.get("success",false) and not old_shift.get("reward_collected",false) else 0
  if s.legacy.reward_pending!=earned or (old_shift.get("reward_collected",false) and not s.legacy.reward_claimed):return false
  if not integer(s.legacy.get("day_number"),1) or not s.legacy.get("phase") in ["PREPARING","RUNNING","CLOSING","SUMMARY"] or not number(s.legacy.get("elapsed"),0,300) or not number(s.legacy.get("closing_remaining"),0,15):return false
 if s.has("preferences"):
  if not s.preferences is Dictionary:return false
  for key in s.preferences:
   if not LegacyStore.Session.valid_preference(key,s.preferences[key]):return false
  for key in LegacyStore.Session.DEFAULT_PREFERENCES:
   if not s.preferences.has(key):return false
 if s.has("upgrades"):
  if not s.upgrades is Dictionary or s.upgrades.size()!=LegacyStore.Session.UPGRADES.size():return false
  for key in LegacyStore.Session.UPGRADES:
   var maximum_level: int=Career.EQUIPMENT_PRICES.size() if s.has("economy") and key in ["grind","brew","milk","ads"] else LegacyStore.Session.UPGRADES[key]
   if not integer(s.upgrades.get(key),0,maximum_level):return false
 if s.has("career"):
  var c=s.career
  if not c is Dictionary or not c.get("owned_modules") is Array or not c.get("equipped_modules") is Array or c.equipped_modules.size()>2 or c.owned_modules.size()>100:return false
  for key in c:
   if not key in ["owned_modules","equipped_modules"]:return false
  var owned={};var equipped={}
  for module in c.owned_modules:
   if not text(module,80) or module=="" or owned.has(module):return false
   owned[module]=true
  for module in c.equipped_modules:
   if not text(module,80) or not owned.has(module) or equipped.has(module):return false
   equipped[module]=true
 if s.has("economy") and not Career.valid(s.economy,s):return false
 var duration=Career.effects(s).coins
 var wish_seconds=Career.wish_seconds(s)
 var maximum=Career.maximum_receipt(s) if s.has("economy") else 108
 var minimum=Career.base_price(s,"espresso",false)/2
 var patience_min=18 if s.get("shift",{}).get("market_rules",0)==1 else 30
 if s.has("economy"):
  var expected=Career.targets(s,s.cup.recipe)
  for n in range(3):
   if s.cup.targets[n]!=expected[n]:return false
  if s.cup.get("cooling_seconds",1.0)!=Career.effects(s).heat:return false
 elif s.cup.get("cooling_seconds",1.0)!=1.0:return false
 if s.has("migration"):
  for key in ["grind","brew","milk","ads"]:
   if s.upgrades[key]<old.upgrades[key]:return false
 var histories={};var history_cups={}
 for n in range(6):
  var key="guest-%02d"%(n+1)
  var p=s.profiles.get(key)
  if not p is Dictionary or not p.get("mood") in MOODS or not text(p.get("last_reaction")) or not integer(p.get("relationship"),-100,100) or not integer(p.get("visits")) or not number(p.get("trust_l"),0,1) or not PRICES.has(p.get("favorite")):return false
  if not p.get("history") is Array or p.history.size()>20:return false
  if s.has("migration") and (not p.has("legacy_history") or p.visits<old.profiles[key].visits or p.favorite!=old.profiles[key].favorite):return false
  if p.has("legacy_history"):
   if old.is_empty() or p.legacy_history!=old.profiles[key].history:return false
  for h in p.history:
   if not h is Dictionary or h.get("schema")!=2 or not id(h.get("visit_id"),s) or not id(h.get("cup_id"),s) or h.visit_id==h.cup_id or h.cup_id==s.cup_id or histories.has(int(h.visit_id)) or history_cups.has(int(h.cup_id)):return false
   for k in ["Q","C","T","R"]:
    if not number(h.get(k),0,1):return false
   if not number(h.get("J"),0,100) or not text(h.get("balance_version"),80):return false
   histories[int(h.visit_id)]={"customer_id":key,"cup_id":int(h.cup_id),"entry":h};history_cups[int(h.cup_id)]=true
 if s.has("economy"):
  var total_visits=0
  for customer in s.profiles:
   total_visits+=int(s.profiles[customer].visits)
   if s.economy.goals[customer]>s.profiles[customer].visits:return false
  if s.economy.fame>(6+Career.passive_level(s,"fame"))*total_visits:return false
 var identities={int(s.cup_id):true};var visits={};var people={};var payments={};var cups={}
 for v in s.visits:
  if not v is Dictionary or not id(v.get("id"),s) or identities.has(int(v.id)) or not s.profiles.has(v.get("customer_id")) or people.has(v.customer_id) or not PRICES.has(v.get("wish_recipe")):return false
  if not v.get("state") in ["WAITING","PAYMENT","DEPARTING"] or not v.get("reaction_applied") is bool or not integer(v.get("payment_id")):return false
  if not number(v.get("arrived_at"),0,s.clock) or not number(v.get("patience_budget"),patience_min,120*Career.patience_factor(s)) or not number(v.get("bubble_until"),v.arrived_at,s.clock+wish_seconds):return false
  if s.has("economy"):
   if not v.get("gift") is bool or not v.get("critic") is bool:return false
   if s.economy.gifts[v.customer_id]:return false
   if v.critic and (s.shift.event_id!="critic" or not s.economy.critic_spawned):return false
  elif v.has("gift") or v.has("critic"):return false
  if v.has("wish_shown_at"):
   if not number(v.wish_shown_at,-1,s.clock) or v.wish_shown_at!=-1 and v.wish_shown_at<v.arrived_at:return false
   if v.wish_shown_at<0 and absf(v.bubble_until-v.arrived_at-wish_seconds)>0.000001:return false
  if v.has("reaction_until") and (not number(v.reaction_until,0,s.clock+3) or not v.has("evaluation")):return false
  var historical=histories.get(int(v.id),{})
  if not historical.is_empty() and historical.customer_id!=v.customer_id:return false
  if v.state=="WAITING":
   if v.reaction_applied or v.payment_id!=0 or v.has("evaluation") or not historical.is_empty() or s.clock>=v.arrived_at+v.patience_budget:return false
  elif not v.reaction_applied:return false
  if v.has("evaluation") and not score(v.evaluation):return false
  if v.state=="PAYMENT" and v.payment_id==0:return false
  if v.state=="DEPARTING" and v.payment_id==0 and (not historical.is_empty() or v.has("evaluation")):return false
  if v.has("legacy_delivery") and (v.legacy_delivery!=true or old.is_empty() or v.payment_id==0 or old.order.state!="PAYMENT" or v.customer_id!=old.order.customer_id):return false
  if v.payment_id>0 and not v.get("legacy_delivery",false):
   if historical.is_empty() or not v.has("evaluation"):return false
   for key in ["Q","J","C","T","R"]:
    if absf(historical.entry[key]-v.evaluation[key])>0.000001:return false
  if v.payment_id>0 and not v.has("evaluation"):
   if old.is_empty() or v.get("legacy_delivery")!=true or old.order.state!="PAYMENT" or v.customer_id!=old.order.customer_id:return false
  identities[int(v.id)]=true;people[v.customer_id]=true;visits[int(v.id)]=v
 for p in s.payments:
  if not p is Dictionary or not id(p.get("id"),s) or identities.has(int(p.id)) or not id(p.get("visit_id"),s) or not visits.has(int(p.visit_id)) or payments.has(int(p.id)) or not id(p.get("cup_id"),s) or cups.has(int(p.cup_id)):return false
  var v=visits[int(p.visit_id)]
  if v.payment_id!=p.id or not v.reaction_applied:return false
  if not p.get("state") in ["PENDING","COLLECTED","EXPIRED","REFUSED"] or not number(p.get("deadline"),0,s.clock+duration):return false
  if not integer(p.get("base"),0,1000) or not integer(p.get("combo"),1,2) or not integer(p.get("tip"),0,1000) or not integer(p.get("amount"),0,1000) or p.amount!=p.base*p.combo+p.tip:return false
  var discounted=p.has("discounted")
  if discounted and p.discounted!=true:return false
  if v.get("legacy_delivery",false):
   if discounted or old.is_empty() or p.amount!=old.order.payment.amount:return false
  else:
   var expected=0 if v.get("gift",false) else Career.base_price(s,v.wish_recipe,v.get("critic",false))
   if discounted:
    if v.get("gift",false) or v.evaluation.R>=1.0 or p.tip!=0:return false
    expected=Career.substitute_price(expected,v.evaluation)
   if p.base!=expected or p.combo!=1 or histories[int(v.id)].cup_id!=p.cup_id:return false
   if (p.state=="REFUSED")!=(discounted and expected==0):return false
   var issued_at=float(v.arrived_at)+(1.0-float(v.evaluation.W))*float(v.patience_budget)
   if absf(float(p.deadline)-issued_at-duration)>0.000001:return false
   var relationship=int(s.profiles[v.customer_id].relationship)
   var allowed_tip=Career.tip_amount(s,int(p.base),relationship)
   if p.tip>0 and (v.evaluation.J<75 or p.tip!=allowed_tip):return false
   if v.get("gift",false) and (p.amount!=0 or p.state!="COLLECTED"):return false
  if p.state=="REFUSED" and not discounted:return false
  if p.state=="PENDING":
   if v.state!="PAYMENT" or p.deadline<=s.clock:return false
  elif v.state!="DEPARTING":return false
  if p.state=="EXPIRED" and p.deadline>s.clock:return false
  identities[int(p.id)]=true;payments[int(p.id)]=p;cups[int(p.cup_id)]=true
 for cup_id in cups:
  if identities.has(cup_id):return false
 for v in s.visits:
  if v.payment_id>0 and (not payments.has(int(v.payment_id)) or payments[int(v.payment_id)].visit_id!=v.id):return false
 for cup_id in history_cups:
  if identities.has(cup_id):return false
 for visit_id in histories:
  if visit_id==s.cup_id or payments.has(visit_id):return false
 if s.has("shift"):
  if not CareerShift.valid(s.shift,float(s.clock),int(s.next_id),minimum,maximum,duration,s.has("economy")):return false
  for key in ["summary_id","last_summary_id"]:
   var sid=int(s.shift[key])
   if sid>0 and (identities.has(sid) or histories.has(sid) or history_cups.has(sid) or cups.has(sid)):return false
  if s.shift.phase in ["PREPARING","SUMMARY"] and (not s.visits.is_empty() or not s.payments.is_empty()):return false
  if s.shift.phase=="PREPARING" and s.cup.first_tap>=0:return false
  var pending=0;var waiting=0;var collected=0;var expired=0;var refused=0;var known_earnings=0;var known_gifts=0
  for v in s.visits:
   if v.arrived_at<s.shift.started_at or v.arrived_at>=s.shift.started_at+300:return false
   if v.state=="WAITING":waiting+=1
  for p in s.payments:
   if p.state=="PENDING":pending+=1
   elif p.state=="COLLECTED":
    collected+=1;known_earnings+=int(p.amount)
    if p.base==0:known_gifts+=1
   elif p.state=="EXPIRED":expired+=1
   elif p.state=="REFUSED":refused+=1
   if p.deadline>s.shift.started_at+315+duration:return false
  var total_refused=int(s.shift.stats.get("refused",0))
  if refused>total_refused or pending!=s.shift.stats.served-s.shift.stats.collected-s.shift.stats.expired-total_refused:return false
  if collected>s.shift.stats.collected or expired>s.shift.stats.expired:return false
  var gifted=int(s.shift.stats.get("gifted",0))
  if known_gifts>gifted or collected-known_gifts>s.shift.stats.collected-gifted:return false
  var unrecorded=(s.shift.stats.collected-gifted)-(collected-known_gifts)
  var remainder=s.shift.stats.earned-known_earnings
  if remainder<minimum*unrecorded or remainder>maximum*unrecorded:return false
  if s.has("economy"):
   var critics=0
   for v in s.visits:
    if v.critic:critics+=1
   if critics>1:return false
  if s.shift.phase=="CLOSING" and pending==0 and waiting==0:return false
  if s.shift.phase=="CLOSING" and s.clock>=s.shift.started_at+315:
   for v in s.visits:
    if v.state=="WAITING":return false
 return true
