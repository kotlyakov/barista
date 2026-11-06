extends SceneTree
const Service=preload("res://orders/service.gd")
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok: failures+=1;push_error(text)
func _init() -> void:
 if not ResourceLoader.exists("res://persistence/service_schema.gd"):
  print("FAIL: external v2 validation absent");quit(1);return
 var schema=load("res://persistence/service_schema.gd")
 var s=Service.new()
 check(schema.valid(JSON.parse_string(JSON.stringify(s.snapshot()))),"empty JSON snapshot valid")
 s.spawn_visit("guest-01","latte")
 s.tap(2)
 var snapshot=s.snapshot()
 check(schema.valid(snapshot),"independent cup recipe and guest wish valid")
 for field in snapshot:
  var bad=snapshot.duplicate(true);bad.erase(field)
  check(not schema.valid(bad),"required field missing: "+field)
 for value in [-1,INF,NAN,"5",true,1.2]:
  var bad=snapshot.duplicate(true);bad.money=value
  check(not schema.valid(bad),"invalid wallet value")
 var bad=snapshot.duplicate(true);bad.visits.append(bad.visits[0].duplicate(true))
 check(not schema.valid(bad),"duplicate profile and visit rejected")
 bad=snapshot.duplicate(true);bad.next_id=bad.cup_id
 check(not schema.valid(bad),"next ID cannot collide")
 bad=snapshot.duplicate(true);bad.rng_state="99999999999999999999999999999"
 check(not schema.valid(bad),"RNG overflow cannot silently wrap")
 bad=snapshot.duplicate(true);bad.profiles["guest-01"].trust_l=2
 check(not schema.valid(bad),"trust bounded")
 bad=snapshot.duplicate(true);bad.visits[0].state="PAYMENT"
 check(not schema.valid(bad),"payment state without payment rejected")
 bad=snapshot.duplicate(true);bad.cup.first_tap=0;bad.cup.last_tap=2;bad.cup.heat_at[1]=1;bad.clock=2
 check(not schema.valid(bad),"single event cannot have contradictory timestamps")
 s.take_cup();s.deliver(s.data.cup_id,s.data.visits[0].id)
 var served=s.snapshot()
 check(schema.valid(JSON.parse_string(JSON.stringify(served))),"served history/payment survives JSON")
 bad=served.duplicate(true);bad.payments[0].visit_id=999
 check(not schema.valid(bad),"orphan payment rejected")
 bad=served.duplicate(true);bad.payments[0].cup_id=bad.cup_id
 check(not schema.valid(bad),"delivered cup cannot be current working cup")
 bad=served.duplicate(true);bad.payments[0].amount+=1
 check(not schema.valid(bad),"amount must equal base*combo+tip")
 bad=served.duplicate(true);bad.visits[0].evaluation.C=0.9
 check(not schema.valid(bad),"inconsistent C cannot silently change future patience")
 check(Service.restore(bad)==null,"public restore rejects invalid external snapshot")
 bad=served.duplicate(true)
 bad.visits[0].state="WAITING";bad.visits[0].payment_id=0;bad.visits[0].reaction_applied=false;bad.visits[0].erase("evaluation");bad.payments=[]
 check(not schema.valid(bad),"completed history forbids replaying the same visit as waiting")
 bad=served.duplicate(true);bad.next_id+=2;bad.payments[0].cup_id=bad.next_id-1
 check(not schema.valid(bad),"payment cup must agree with recorded history")
 bad=served.duplicate(true);bad.payments[0].combo=2;bad.payments[0].tip=800;bad.payments[0].amount=980
 check(not schema.valid(bad),"bad milk-only drink cannot get combo or excessive tips")
 var two=Service.new();two.spawn_visit("guest-01","cappuccino");two.spawn_visit("guest-02","cappuccino")
 for v in two.data.visits:
  for station in range(3):
   for n in range(two.cup.targets[station]):two.tap(station)
  two.take_cup();two.deliver(two.data.cup_id,v.id)
 bad=two.snapshot();bad.visits[1].payment_id=bad.payments[0].id;bad.payments.remove_at(1)
 check(not schema.valid(bad),"two visits cannot share one payment")
 bad=served.duplicate(true);bad.career={"owned_modules":["a","b","c"],"equipped_modules":["a","b","c"]}
 check(not schema.valid(bad),"more than two modules rejected")
 if failures==0:print("PASS: external schema, numeric types, unique references, C/J consistency, timestamps and restore boundary")
 quit(0 if failures==0 else 1)
