extends SceneTree
const Repo=preload("res://persistence/repository_v2.gd")

func _init() -> void:
 call_deferred("run")

func run() -> void:
 var path="user://ten-upgrades-"+str(Time.get_ticks_usec())
 var repo=Repo.new(path)
 repo.apply("enable_career")
 repo.apply("enable_development")
 repo.session.data.money=200000
 if not repo.checkpoint():quit(1);return
 for station in ["grind","brew","milk","ads"]:
  for level in range(10):
   if not repo.apply("buy_equipment",[station,level]):
    push_error("Purchase failed: %s level %d" % [station,level+1]);quit(1);return
   if repo.apply("buy_equipment",[station,level]):quit(1);return
  if repo.apply("buy_equipment",[station,10]):quit(1);return
 var reopened=Repo.new(path)
 if not reopened.ready or reopened.session.data.upgrades.ads!=10 or reopened.session.cup.targets!=[2,6,1]:
  push_error("Level 10 or tap targets did not survive a reopen");quit(1);return
 print("PASS: 40 transactional upgrades, stale and maximum guards, reload and tap floor")
 quit()
