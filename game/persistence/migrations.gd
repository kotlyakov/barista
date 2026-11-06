extends RefCounted
const Service=preload("res://orders/service.gd")
const LegacyStore=preload("res://persistence/store.gd")
const Schema=preload("res://persistence/service_schema.gd")
# This is a review artifact, not an approved production migration policy.
static func preview(old: Dictionary) -> Dictionary:
 if not LegacyStore.valid(old):return {"ok":false,"error":"INVALID_LEGACY"}
 if old.order.state in ["PAYMENT","COLLECTED","UNPAID"]:
  var p=old.order.payment
  for key in ["base","tip","combo"]:
   if p.has(key) and not Schema.integer(p[key],1 if key=="combo" else 0,2 if key=="combo" else 1000):return {"ok":false,"error":"INVALID_LEGACY_PAYMENT"}
  if int(p.get("base",p.amount))*int(p.get("combo",1))+int(p.get("tip",0))!=p.amount:return {"ok":false,"error":"INVALID_LEGACY_PAYMENT"}
 var s=Service.new()
 s.data.money=int(old.money);s.data.streak=int(old.streak)
 s.data.clock=float(old.clock)+120
 s.data.next_id=int(old.next_id)
 s.data.cup_id=s.allocate_id()
 s.data.rng_state=old.rng_state
 s.data.upgrades=old.upgrades.duplicate(true)
 s.data.preferences=LegacyStore.Session.DEFAULT_PREFERENCES.duplicate()
 for key in old.get("preferences",{}):s.data.preferences[key]=old.preferences[key]
 for key in old.profiles:
  var profile=old.profiles[key].duplicate(true)
  profile.trust_l=0.5
  profile.legacy_history=profile.history.duplicate(true)
  profile.history=[]
  s.data.profiles[key]=profile
 var shift=old.get("shift",{})
 var pending=200 if shift.get("mode")=="SUMMARY" and shift.get("success",false) and not shift.get("reward_collected",false) else 0
 s.data.legacy={"review_only":true,"source_snapshot":old.duplicate(true),"source_hash":JSON.stringify(old).sha256_text(),"temperature_policy":"COLD_REVIEW","reward_pending":pending,"reward_claimed":shift.get("reward_collected",false),"day_number":1,"phase":{"SHOP":"PREPARING","RUNNING":"RUNNING","CLOSING":"CLOSING","SUMMARY":"SUMMARY","FINISHED":"PREPARING"}.get(shift.get("mode","SHOP")),"elapsed":clampf((480-float(shift.get("remaining",480)))/480*300,0,300),"closing_remaining":15 if shift.get("mode")=="CLOSING" else 0}
 var o=old.order
 s.cup=Service.Cup.new(o.recipe)
 if o.state=="BREWING":
  for i in range(old.brew.taps.size()):
   s.cup.taps[i]=int(old.brew.taps[i]);s.cup.targets[i]=int(old.brew.targets[i])
  if s.cup.taps[0]+s.cup.taps[1]+s.cup.taps[2]>0:
   s.cup.first_tap=float(o.first_tap)+120 if o.first_tap>=0 else s.data.clock
   s.cup.last_tap=s.cup.first_tap
   for i in range(2):
    var station=i+1
    if s.cup.taps[station]==0:continue
    s.cup.heat_at[i]=s.data.clock-9
    s.cup.heat_start_level[i]=clampi(10-int(ceil(9*clampf(float(s.cup.taps[station])/s.cup.targets[station],0,1))),1,10)
    s.cup.first_tap=minf(s.cup.first_tap,s.cup.heat_at[i])
    s.cup.last_tap=maxf(s.cup.last_tap,s.cup.heat_at[i])
   if s.cup.taps[0]+s.cup.taps[1]+s.cup.taps[2]==1:s.cup.last_tap=s.cup.first_tap
  var waiting=o.patience>0
  s.data.visits.append({"id":s.allocate_id(),"customer_id":o.customer_id,"wish_recipe":o.recipe,"state":"WAITING" if waiting else "DEPARTING","patience_budget":75.0,"arrived_at":s.data.clock-(75-float(o.patience)),"bubble_until":s.data.clock,"reaction_applied":not waiting,"payment_id":0})
 elif o.state=="PAYMENT":
  var visit_id=s.allocate_id();var payment_id=s.allocate_id();var delivered_cup=s.allocate_id()
  var remaining=maxf(0,float(o.payment.deadline)-float(old.clock))
  s.data.visits.append({"id":visit_id,"customer_id":o.customer_id,"wish_recipe":o.recipe,"state":"PAYMENT" if remaining>0 else "DEPARTING","patience_budget":75.0,"arrived_at":s.data.clock,"bubble_until":s.data.clock,"reaction_applied":true,"payment_id":payment_id,"legacy_delivery":true})
  s.data.payments.append({"id":payment_id,"visit_id":visit_id,"cup_id":delivered_cup,"base":int(o.payment.get("base",o.payment.amount)),"tip":int(o.payment.get("tip",0)),"combo":int(o.payment.get("combo",1)),"amount":int(o.payment.amount),"deadline":s.data.clock+remaining,"state":"PENDING" if remaining>0 else "EXPIRED"})
 var snapshot_data=s.snapshot()
 if not Schema.valid(snapshot_data):return {"ok":false,"error":"LEGACY_REVIEW_INCONSISTENT"}
 return {"ok":true,"snapshot":snapshot_data,"warnings":["REVIEW_ONLY","UNKNOWN_HEAT_ASSUMED_COLD","LEGACY_EFFECTS_DEFERRED","SHIFT_MAPPING_FOR_REVIEW"]}
