extends SceneTree
var failures=0
var Service
func check(ok: bool,message: String) -> void:
 if not ok: failures+=1; push_error(message)
func near(a: float,b: float) -> bool:
 return absf(a-b)<0.000001
func fill(s) -> void:
 for station in range(3):
  if station==2 and s.cup.recipe=="espresso": continue
  for n in range(s.cup.targets[station]): check(s.tap(station),"prepare actual working cup")
func _init() -> void:
 if not ResourceLoader.exists("res://orders/service.gd"):
  print("FAIL: independent delivery model is absent")
  quit(1)
  return
 Service=load("res://orders/service.gd")
 if Service==null: quit(1); return
 test_free_delivery_and_payments()
 test_real_contents()
 test_wrong_receipts()
 test_expired_recipient()
 test_history()
 if failures==0: print("PASS: free recipients, unique payments, expiry, thermal serving snapshot, literal C/L history, relationships and restore idempotence")
 quit(0 if failures==0 else 1)

func test_free_delivery_and_payments() -> void:
 var s=Service.new()
 for n in range(5): s.spawn_visit("guest-%02d"%(n+1),"cappuccino")
 check(not s.take_cup(),"empty cup cannot be delivered despite evaluator snapshot validity")
 var recipients=[s.data.visits[4].id,s.data.visits[0].id,s.data.visits[2].id]
 var payment_ids=[]
 for id in recipients:
  fill(s)
  var cup_id=s.data.cup_id
  check(s.take_cup(),"take prepared cup")
  check(s.deliver(cup_id,id),"any first/middle/last guest can receive the drink")
  check(not s.deliver(cup_id,id),"same cup cannot be served twice")
  check(s.cup.is_empty() and s.data.cup_id!=cup_id,"successful delivery creates a new unrelated cup")
  var v=s.find_visit(id)
  var p=s.data.payments.back()
  check(p.id!=id and p.id!=cup_id and v.payment_id==p.id,"cup/visit/payment have distinct IDs")
  check(not p.id in payment_ids,"each drink has an independent payment")
  payment_ids.append(p.id)
 check(s.data.money==0,"delivery does not automatically collect money")
 check(s.data.payments[0].amount==80 and s.data.payments[1].amount==80 and s.data.payments[2].amount==88,"third good delivery earns one tip")
 var profile=s.data.profiles[s.find_visit(recipients[0]).customer_id].duplicate(true)
 check(s.collect(payment_ids[0]) and not s.collect(payment_ids[0]),"payment collected once")
 check(s.data.money==80 and s.data.profiles[profile_id(s,recipients[0])]==profile,"collection does not reapply C/L/mood")
 s.advance(12)
 check(s.data.money==80 and not s.collect(payment_ids[1]),"deadline expires coins without payout")
 var loaded=Service.restore(JSON.parse_string(JSON.stringify(s.snapshot())))
 check(loaded!=null and loaded.data.money==80,"reload preserves wallet")
 if loaded!=null:
  check(not loaded.collect(payment_ids[0]) and not loaded.collect(payment_ids[1]),"reload does not resurrect collected/expired payment")
  check(loaded.finish_departure(recipients[0]),"served guest leaves after payment")
  check(not loaded.collect(payment_ids[0]),"pruned terminal payment cannot be collected again")

func profile_id(s,visit_id: int) -> String:
 return s.find_visit(visit_id).customer_id

func test_expired_recipient() -> void:
 var s=Service.new()
 s.spawn_visit("guest-01","cappuccino")
 var a=s.data.visits[0].id
 s.advance(2)
 s.spawn_visit("guest-02","cappuccino")
 var b=s.data.visits[1].id
 s.advance(72)
 fill(s)
 s.take_cup()
 var cup_id=s.data.cup_id
 s.advance(1)
 var before=s.snapshot()
 check(s.find_visit(a).state=="DEPARTING" and s.find_visit(b).state=="WAITING","each guest has an independent deadline")
 check(not s.deliver(cup_id,a),"known expired visit rejected at exact patience cutoff")
 check(s.snapshot()==before and s.cup.carrying,"stale recipient cannot consume cup, create payment or change history")
 check(s.deliver(cup_id,b),"same carried cup can immediately be delivered to still-waiting guest")

func test_real_contents() -> void:
 var s=Service.new()
 s.spawn_visit("guest-01","espresso")
 var id=s.data.visits[0].id
 s.select_recipe("latte")
 s.tap(2)
 s.take_cup()
 check(s.return_cup() and s.tap(0),"miss allows adding grounds to milk")
 s.take_cup()
 check(s.deliver(s.data.cup_id,id),"wrong actual contents are still deliverable")
 var result=s.find_visit(id).evaluation
 check(result.contents=="milk_grounds" and result.R==0,"served contents compared to selected recipient")
 check(s.data.payments[0].amount==0 and s.data.payments[0].state=="REFUSED","unfinished drink is refused with no money to collect")
 var cold=Service.new()
 cold.spawn_visit("guest-01","cappuccino")
 fill(cold)
 cold.take_cup()
 cold.advance(9)
 check(cold.deliver(cold.data.cup_id,cold.data.visits[0].id),"cup can cool during drag")
 var evaluated=cold.data.visits[0].evaluation
 check(evaluated.T==0 and evaluated.J<25,"delivery freezes actual time/temperature/waiting, not pickup state")
 check(near(evaluated.C,0.25),"literal cold C is .25 regardless of waiting")
 check(cold.data.profiles["guest-01"].mood=="very_unhappy","cold ideal taste cannot display a smile")
 check(cold.data.profiles["guest-01"].last_reaction=="Остыло","cold drink uses a meaningful Russian reaction")

func test_history() -> void:
 var s=Service.new()
 var expected_l=[0.625,0.71875,0.7890625,0.841796875]
 for i in range(4):
  s.spawn_visit("guest-01","cappuccino")
  var visit_id=s.data.visits[0].id
  fill(s)
  s.take_cup()
  s.deliver(s.data.cup_id,visit_id)
  var v=s.find_visit(visit_id)
  check(near(v.evaluation.C,1) and near(s.data.profiles["guest-01"].trust_l,expected_l[i]),"literal perfect C and successive trust history")
  check(s.collect(v.payment_id) and s.finish_departure(visit_id),"complete visit")
  s=Service.restore(JSON.parse_string(JSON.stringify(s.snapshot())))
 check(s.spawn_visit("guest-01","cappuccino"),"regular returns after four drinks")
 var v=s.data.visits[0]
 check(near(v.patience_budget,105.76171875),"four ideal drinks produce fixed next patience")
 check(s.data.profiles["guest-01"].relationship==32,"ideal relationship is independent from trust L")
 var bad=Service.new()
 var expected_bad=[0.375,0.28125,0.2109375,0.158203125]
 for i in range(4):
  bad.spawn_visit("guest-01","cappuccino")
  var id=bad.data.visits[0].id
  fill(bad)
  for station in range(3):
   for n in range(10): bad.tap(station)
  bad.take_cup()
  bad.deliver(bad.data.cup_id,id)
  check(bad.find_visit(id).evaluation.C==0 and near(bad.data.profiles["guest-01"].trust_l,expected_bad[i]),"all-zero quality gives literal zero C without fabricated waiting penalty")
  check(bad.data.payments[0].tip==0,"bad drink cannot earn loyalty tips")
  bad.collect(bad.find_visit(id).payment_id)
  bad.finish_departure(id)
 bad.spawn_visit("guest-01","cappuccino")
 check(near(bad.data.visits[0].patience_budget,44.23828125),"poor history gives literal next patience")
 var milk=Service.new()
 milk.spawn_visit("guest-01","cappuccino")
 fill(milk)
 for n in range(6):milk.tap(2)
 milk.take_cup()
 milk.deliver(milk.data.cup_id,milk.data.visits[0].id)
 check(near(milk.data.visits[0].evaluation.C,0.5248) and milk.data.profiles["guest-01"].mood=="disappointed","overheated milk history and expression use C/J")
 check("кипячёный" in milk.data.profiles["guest-01"].last_reaction.to_lower(),"reaction describes milk defect instead of an unrelated mood label")


func test_wrong_receipts() -> void:
 var s=Service.new()
 s.enable_career()
 check(s.start_shift(1),"start career shift for wrong receipts")
 var visit=s.data.visits[0]
 var other="cappuccino" if visit.wish_recipe=="espresso" else "espresso"
 s.select_recipe(other)
 fill(s)
 s.take_cup()
 check(s.deliver(s.data.cup_id,visit.id),"well made substitute delivered")
 var receipt=s.data.payments[0]
 var price=s.Career.base_price(s.data,visit.wish_recipe,visit.get("critic",false))
 check(receipt.amount==price/2 and receipt.tip==0 and receipt.state=="PENDING","wrong hot drink earns half the order price, without tip")
 var saved=s.snapshot()
 var reloaded=Service.restore(saved)
 check(reloaded!=null,"discounted receipt survives reload")
 if reloaded!=null:
  check(reloaded.collect(receipt.id) and not reloaded.collect(receipt.id),"discounted receipt collected exactly once")
  check(reloaded.finish_departure(visit.id) and Service.restore(reloaded.snapshot())!=null,"partial revenue remains valid after guest leaves")
 var old=saved.duplicate(true)
 old.payments[0].erase("discounted")
 old.payments[0].base=price
 old.payments[0].amount=price
 var prior=Service.restore(old)
 check(prior!=null and prior.data.payments[0].amount==price,"already issued old full-price receipt remains collectible")
 check(Service.restore(s.snapshot())!=null,"current profile remains valid")
 var refused=Service.new()
 refused.enable_career()
 refused.start_shift(1)
 refused.tap(0)
 refused.take_cup()
 var id=refused.data.visits[0].id
 check(refused.deliver(refused.data.cup_id,id),"unfinished drink handed over")
 var zero=refused.data.payments[0]
 check(zero.state=="REFUSED" and not refused.collect(zero.id) and refused.data.shift.stats.collected==0,"refused receipt does not create collectible money or count as collection")
 var reopened=Service.restore(refused.snapshot())
 check(reopened!=null,"refused receipt survives career reload")
 if reopened!=null:
  reopened.finish_departure(id)
  reopened.advance(400)
  check(reopened.data.shift.phase=="SUMMARY" and Service.restore(reopened.snapshot())!=null,"refusal cannot block shift summary")
