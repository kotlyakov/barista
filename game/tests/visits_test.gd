extends SceneTree
var failures=0
var Service
func check(ok: bool,message: String) -> void:
 if not ok: failures+=1; push_error(message)
func _init() -> void:
 if not ResourceLoader.exists("res://orders/service.gd"):
  print("FAIL: independent visits model is absent")
  quit(1)
  return
 Service=load("res://orders/service.gd")
 if Service==null: quit(1); return
 var s=Service.new()
 for n in range(5):
  check(s.spawn_visit(),"five independent visitors can enter")
  if n==0:
   var only=s.snapshot()
   check(not s.spawn_visit(s.data.visits[0].customer_id),"duplicate profile rejected even with four free slots")
   check(s.snapshot()==only,"duplicate rejection cannot consume RNG or allocate another visit")
 var ids=[]
 for v in s.data.visits:
  check(not v.customer_id in ids,"same hero cannot be present twice")
  ids.append(v.customer_id)
 check(not s.spawn_visit() and s.data.visits.size()==5,"sixth visitor rejected without hidden queue")
 var first=s.data.visits[0].duplicate(true)
 check(not s.spawn_visit(first.customer_id),"explicit event cannot duplicate a present hero")
 var recipe=s.cup.recipe
 var patience=first.patience_budget
 s.advance(2)
 check(s.remind_wish(first.id),"tap reminds independent wish")
 var reminded=s.find_visit(first.id)
 check(reminded.bubble_until==5 and reminded.patience_budget==patience and reminded.arrived_at==0,"reminder lasts3s and never resets patience")
 check(s.cup.recipe==recipe,"guest reminder does not select a recipe")
 var before=s.snapshot()
 s.advance(100,true)
 check(s.snapshot()==before,"pause freezes every active timer")
 check(s.tap(2) and s.cup.can_take(),"work cup exists independently from guests")
 s.advance(73)
 check(s.find_visit(first.id).state=="DEPARTING","patience expires even after preparation started")
 check(s.cup.can_take() and s.cup.taps[2]==1,"leaving guest does not remove working cup")
 check(s.data.profiles[first.customer_id].trust_l==0.5,"no drink means no fabricated C history")
 check(s.data.profiles[first.customer_id].relationship==-5,"leaving relationship applied once")
 s.advance(10)
 check(s.data.profiles[first.customer_id].relationship==-5,"leaving not applied again")
 check(not s.spawn_visit(),"departing figure occupies its slot until actual animation ends")
 check(s.finish_departure(first.id) and not s.finish_departure(first.id),"departure releases a slot once")
 check(s.spawn_visit(first.customer_id,"latte"),"same permanent hero may return on a new visit")
 var next=s.data.visits.back()
 check(next.id!=first.id and next.wish_recipe=="latte","new visit has independent immutable ID and wish")
 check(next.patience_budget==75,"leaving did not change trust-derived patience")
 s.data.visits.reverse()
 check(s.find_visit(next.id).customer_id==first.customer_id,"slot reordering does not change identity")
 var loaded=Service.restore(JSON.parse_string(JSON.stringify(s.snapshot())))
 check(loaded!=null and loaded.cup.taps==[0,0,1],"JSON reload restores cup and visits")
 if loaded!=null:
  check(loaded.data.profiles[first.customer_id].relationship==-5 and loaded.data.visits.size()==5,"reload does not repeat leave effect")
 var invalid=s.snapshot()
 check(not s.remind_wish(-1) and not s.deliver(s.data.cup_id,-1) and not s.collect(-1),"unknown IDs rejected")
 s.advance(-1)
 s.advance(NAN)
 check(s.snapshot()==invalid,"invalid clock input and IDs do not mutate state")
 var pause=Service.new()
 pause.spawn_visit("guest-01","cappuccino")
 pause.tap(0)
 pause.take_cup()
 pause.advance(20,true)
 check(pause.data.clock==0 and not pause.cup.carrying,"pause returns the cup without advancing active time")
 check(not pause.deliver(pause.data.cup_id,pause.data.visits[0].id),"pause cannot leave a hidden carried cup eligible for delivery")
 check(pause.tap(2) and pause.cup.taps==[1,0,1],"cooking resumes after pause without another pickup")
 if failures==0: print("PASS: five unique visits, independent wishes, reminders, active clocks, departure slots, leave history, JSON reload")
 quit(0 if failures==0 else 1)
