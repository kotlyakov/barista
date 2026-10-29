extends SceneTree
const Session=preload("res://orders/session.gd")
func fill(g) -> void:
 for i in range(g.brew.targets.size()):
  for n in range(g.brew.targets[i]): g.tap(i)
func _init() -> void:
 var g=Session.new()
 if not g.has_method("enable_shift"):
  push_error("FAIL: career shift not integrated")
  quit(1)
  return
 var now=Time.get_unix_time_from_datetime_string("2026-10-29T09:00:00")
 g.enable_shift(now,180)
 assert(not g.tap(0),"shop blocks brewing")
 g.choose_perk(g.shift.data.offers[0])
 assert(g.start_shift())
 assert(g.tap(0))
 g.advance(480,false,now)
 assert(g.shift.data.mode=="CLOSING")
 fill(g);g.take_cup();g.deliver(g.data.order.id,g.data.order.customer_id);g.collect(g.data.order.id)
 g.advance(0.01,false,now)
 assert(g.shift.data.mode=="SUMMARY")
 var profile_before=g.data.profiles.duplicate(true)
 assert(g.collect_reward())
 assert(not g.collect_reward(),"summary cannot duplicate reward")
 g.advance(0.01,false,now+86400)
 assert(g.shift.data.mode=="SHOP" and g.data.profiles==profile_before,"new day preserves moods and history")
 var repo_script=load("res://persistence/repository.gd")
 var repo=repo_script.new("user://training-"+str(Time.get_ticks_usec()))
 assert(not repo.begin_training(),"training unlocks after main shift")
 repo.session.shift.data.mode="FINISHED"
 repo.session.shift.data.reward_collected=true
 repo.checkpoint()
 var main=repo.session.snapshot()
 assert(repo.begin_training())
 fill(repo.session)
 repo.apply("take_cup");repo.apply("deliver",[1,"guest-01"]);repo.apply("collect",[1])
 assert(repo.end_training())
 assert(repo.session.snapshot()==main,"training cannot modify main profile or wallet")
 print("PASS: shop/start/closing/summary, single reward, daily mood persistence, isolated training")
 quit(0)
