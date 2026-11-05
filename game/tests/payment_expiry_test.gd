extends SceneTree
const Repository=preload("res://persistence/repository.gd")
func _init() -> void:
 var directory="user://expiry-"+str(Time.get_ticks_usec())
 var repo=Repository.new(directory,false)
 for i in range(repo.session.brew.targets.size()):
  for n in range(repo.session.brew.targets[i]): assert(repo.apply("tap",[i]))
 assert(repo.apply("take_cup"))
 var id=repo.session.data.order.id
 assert(repo.apply("deliver",[id,"guest-01"]))
 var remaining=repo.session.data.order.payment.deadline-repo.session.data.clock
 repo.advance(remaining-0.25)
 repo.advance(100,true)
 var restored=Repository.new(directory,false)
 assert(restored.session.data.order.state=="PAYMENT","pause and restart preserve the remaining lifetime")
 assert(is_equal_approx(restored.session.data.order.payment.deadline-restored.session.data.clock,0.25))
 restored.advance(0.25)
 assert(restored.session.data.order.state=="UNPAID","coins disappear exactly at the deadline")
 assert(not restored.apply("collect",[id]))
 var after=Repository.new(directory,false)
 assert(after.session.data.order.state=="UNPAID" and after.session.data.money==0,"expired coins must not return or auto-credit after restart")
 assert(not after.apply("collect",[id]))
 after.advance(6)
 assert(after.apply("next_order"))
 assert(after.session.data.money==0 and after.session.data.order.id!=id)
 print("PASS: payment expires at boundary, pause preserves lifetime, restart cannot revive or credit lost coins")
 quit()
