extends SceneTree
const Repo=preload("res://persistence/repository_v2.gd")
func _init() -> void:
 call_deferred("run")

func run() -> void:
 var path="user://passives-"+str(Time.get_ticks_usec())
 var repo=Repo.new(path)
 repo.apply("enable_career")
 repo.apply("enable_development")
 var ids=["tips","espresso","milk_income","fame","relationship","flow","patience","warmth","payment","wish"]
 if repo.apply("buy_passive",["tips",0]):quit(1);return
 repo.session.data.money=100000
 if not repo.checkpoint():quit(1);return
 var stale=Repo.new(path)
 for id in ids:
  if not repo.apply("buy_passive",[id,0]) or repo.apply("buy_passive",[id,0]):
   push_error("Purchase or duplicate guard failed: "+id);quit(1);return
 if stale.apply("buy_passive",["wish",0]):quit(1);return
 var fresh=Repo.new(path)
 var s=fresh.session
 if not fresh.ready or s.data.economy.passives.size()!=10 or s.Career.base_price(s.data,"espresso",false)!=52:
  push_error("Reload or espresso effect failed");quit(1);return
 s.data.shift.event_id="calm"
 s.start_shift(1)
 var v=s.data.visits[0]
 var budget=30+90*s.data.profiles[v.customer_id].trust_l
 if s.buy_passive("tips",1) or not is_equal_approx(v.patience_budget,budget*1.1) or not is_equal_approx(v.bubble_until,3.3) or not is_equal_approx(s.cup.cooling_seconds,1.1):
  push_error("Passive active effects or shift guard failed");quit(1);return
 if not s.Schema.valid(s.snapshot()):
  push_error("A valid live passive snapshot was rejected");quit(1);return
 var profile=s.data.profiles[v.customer_id]
 profile.relationship=30
 s.select_recipe(v.wish_recipe)
 for station in range(3):
  for n in range(s.cup.targets[station]):s.tap(station)
 s.take_cup()
 if not s.deliver(s.data.cup_id,v.id):quit(1);return
 var payment=s.data.payments[0]
 var expected_base=int(floor(s.PRICES[v.wish_recipe]*1.05))
 var expected_tip=int(floor(expected_base*(0.10+0.10*profile.relationship/100.0)*1.10))
 if payment.base!=expected_base or payment.tip!=expected_tip or payment.deadline!=14 or s.data.economy.fame!=2 or profile.relationship!=39:
  push_error("Passive income, tips, payment window, fame or relationship did not reach the real delivery");quit(1);return
 if not s.Schema.valid(s.snapshot()):
  push_error("Delivery snapshot with passive effects rejected");quit(1);return
 print("PASS: ten passive purchases, no duplicate debit, stale rollback, real service effects and reload")
 quit()
