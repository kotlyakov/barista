extends SceneTree
func _init() -> void:
 var script=load("res://persistence/repository.gd")
 var path="user://regression-training-"+str(Time.get_ticks_usec())
 var repo=script.new(path)
 repo.session.data.money=1234
 repo.session.data.upgrades.grind=2
 repo.session.shift.data.mode="FINISHED"
 repo.session.shift.data.reward_collected=true
 repo.checkpoint()
 var main=repo.session.snapshot()
 repo.begin_training()
 repo.restart()
 if not repo.training:
  push_error("FAIL: resetting practice must remain in practice")
  quit(1)
  return
 repo.end_training()
 if repo.session.snapshot()!=main or script.new(path).session.snapshot()!=main:
  push_error("FAIL: training restart changed saved main career")
  quit(1)
  return
 print("PASS: training restart preserves main wallet, upgrades, profile and saved career")
 quit(0)
