extends SceneTree
func _init() -> void:
 var script=load("res://persistence/repository.gd")
 if script==null:
  push_error("FAIL: durable transaction boundary missing")
  quit(1)
  return
 var path="user://test-transaction-"+str(Time.get_ticks_usec())
 var repo=script.new(path,false)
 assert(repo.ready)
 for i in range(repo.session.brew.targets.size()):
  for n in range(repo.session.brew.targets[i]): assert(repo.apply("tap",[i]))
 assert(repo.apply("take_cup"))
 assert(repo.apply("deliver",[1,"guest-01"]))
 var before=repo.session.snapshot()
 repo.store.directory="/proc"
 assert(not repo.apply("collect",[1]))
 assert(repo.session.snapshot()==before,"failed disk write rolls back wallet, order and profile")
 repo.store.directory=path
 assert(repo.apply("collect",[1]))
 repo=script.new(path,false)
 assert(repo.session.data.money==80 and not repo.apply("collect",[1]))
 print("PASS: state changes commit before success; disk failure rolls back; restart cannot duplicate payment")
 quit(0)
