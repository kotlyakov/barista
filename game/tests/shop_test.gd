extends SceneTree
const Session=preload("res://orders/session.gd")
func _init() -> void:
 var g=Session.new()
 if not g.has_method("purchase"):
  push_error("FAIL: shop model missing")
  quit(1)
  return
 g.enable_shift(0,0)
 assert(not g.purchase("grind",0),"cannot spend unearned money")
 g.data.money=5000
 assert(g.purchase("grind",0) and g.data.money==4600)
 assert(not g.purchase("grind",0) and g.data.money==4600,"same offer cannot charge twice")
 assert(g.purchase("grind",1) and g.purchase("grind",2))
 assert(not g.purchase("grind",3),"max level")
 assert(not g.purchase("unknown",0))
 g.shift.data.offers=["brew","milk","patience"]
 g.shift.data.event="rush"
 g.choose_perk("patience")
 assert(g.start_shift())
 assert(g.brew.targets[0]==9)
 assert(not g.purchase("brew",0),"no mid-order changes")
 var repo=load("res://persistence/repository.gd").new("user://shop-"+str(Time.get_ticks_usec()))
 repo.session.data.money=500
 repo.checkpoint()
 repo.store.directory="/proc"
 assert(not repo.apply("purchase",["grind",0]))
 assert(repo.session.data.money==500 and repo.session.data.upgrades.grind==0)
 print("PASS: shop balance, expected-level idempotency, cap, effects, shop-only and disk rollback")
 quit(0)
