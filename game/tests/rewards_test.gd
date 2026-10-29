extends SceneTree
const Session=preload("res://orders/session.gd")
func fill(g) -> void:
 for i in range(g.brew.targets.size()):
  for n in range(g.brew.targets[i]): g.tap(i)
func serve(g) -> void:
 g.take_cup();g.deliver(g.data.order.id,g.data.order.customer_id)
func _init() -> void:
 var g=Session.new()
 fill(g);serve(g)
 if not g.data.order.payment.has("tip"):
  push_error("FAIL: native reward breakdown missing")
  quit(1)
  return
 assert(g.data.order.payment.amount==80 and g.data.order.payment.combo==1,"speed disabled before calibration")
 assert(g.data.streak==1)
 g.collect(g.data.order.id)
 for n in range(2):
  g.advance(6);g.next_order("cappuccino","guest-01");fill(g);serve(g);g.collect(g.data.order.id)
 assert(g.data.streak==3 and g.data.order.payment.tip==9,"third good gives one streak tip")
 var speed=Session.new()
 speed.speed_thresholds={"cappuccino":5.0}
 speed.data.profiles["guest-01"].relationship=42
 fill(speed);speed.advance(5);serve(speed)
 assert(speed.data.order.payment.amount==172 and speed.data.order.payment.tip==12,"combo doubles base only; exact boundary")
 var slow=Session.new()
 slow.speed_thresholds={"cappuccino":5.0}
 fill(slow);slow.advance(5.001);serve(slow)
 assert(slow.data.order.payment.combo==1)
 var poor=Session.new()
 poor.data.streak=8
 poor.data.profiles["guest-01"].relationship=100
 for i in range(poor.brew.targets.size()):
  for n in range(poor.brew.targets[i]+20): poor.tap(i)
 serve(poor)
 assert(poor.data.order.payment.tip==0 and poor.data.streak==0 and poor.data.order.payment.amount==80)
 var late=Session.new()
 late.speed_thresholds={"cappuccino":100.0}
 late.data.profiles["guest-01"].relationship=100
 fill(late);late.advance(36);serve(late)
 assert(late.data.order.payment.tip==0 and late.data.order.payment.combo==1)
 assert(late.data.profiles["guest-01"].mood=="annoyed")
 print("PASS: streak and loyal tips, poor/late exclusion, exact speed threshold, base-only multiplier")
 quit(0)
