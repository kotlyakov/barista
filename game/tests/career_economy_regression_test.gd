extends SceneTree
const S=preload("res://orders/service.gd")
const R=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func make():
 var s=S.new(1);s.enable_career();s.enable_development();return s
func _init():
 var s=make();var bad=s.snapshot();bad.economy.goals["guest-01"]=6
 check(not S.Schema.valid(bad),"reject invented goal progress before any visit")
 bad=s.snapshot();bad.economy.fame=100
 check(not S.Schema.valid(bad),"reject fame beyond actual visit count")
 bad=s.snapshot();bad.economy.critic_spawned=true
 check(not S.Schema.valid(bad),"reject skipped critic marker before start")
 s.data.shift.event_id="critic";s.start_shift(1);bad=s.snapshot();bad.economy.critic_spawned=false
 check(not S.Schema.valid(bad),"reject replayable critic marker during shift")
 bad=s.snapshot();bad.economy.choice=""
 check(not S.Schema.valid(bad),"running choice must be locked")
 bad=s.snapshot();bad.economy.gifts[s.data.visits[0].customer_id]=true
 check(not S.Schema.valid(bad),"reject a new reservation while chosen guest already present")
 for malformed in [null,{},[],1,"RUNNING"]:
  bad=s.snapshot();bad.shift=malformed
  check(not S.Schema.valid(bad),"malformed shift must return false without script errors")
 var v=s.data.visits[0];s.select_recipe(v.wish_recipe)
 for station in range(3 if v.wish_recipe!="espresso" else 2):
  for n in range(s.cup.targets[station]):s.tap(station)
 s.take_cup();s.deliver(s.data.cup_id,v.id);s.advance(8)
 bad=s.snapshot();bad.payments[0].deadline+=8
 check(not S.Schema.valid(bad),"receipt deadline is tied to delivery, not reload time")
 s=make();s.start_shift(1);v=s.data.visits[0];s.select_recipe(v.wish_recipe)
 for station in range(3 if v.wish_recipe!="espresso" else 2):
  for n in range(s.cup.targets[station]):s.tap(station)
 s.take_cup();s.deliver(s.data.cup_id,v.id);s.collect(s.data.payments.back().id);s.finish_departure(v.id);s.advance(400)
 bad=s.snapshot();bad.shift.stats.earned=1
 check(not S.Schema.valid(bad),"completed paid receipt cannot become a one-coin gift in summary")
 var directory="user://economy-review-"+str(Time.get_ticks_usec());var r=R.new(directory,true);r.apply("enable_career")
 var before=r.session.snapshot()
 check(not r.apply("enable_development") and r.session.snapshot()==before,"review repository cannot activate development")
 if failures==0:print("PASS: plausible progress, consumed gifts, fixed critic/choice markers, malformed snapshots, original payment deadline and review gate")
 quit(0 if failures==0 else 1)
