extends SceneTree
class FailedStore:
 extends RefCounted
 func save(_snapshot: Dictionary,_expected=-1) -> Dictionary:return {"ok":false,"error":"FORCED_WRITE"}
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok:failures+=1;push_error(text)
func _init() -> void:
 if not ResourceLoader.exists("res://persistence/repository_v2.gd"):
  print("FAIL: v2 transaction repository absent");quit(1);return
 var Repo=load("res://persistence/repository_v2.gd")
 var path="user://test-v2-repo-"+str(Time.get_ticks_usec())
 var r=Repo.new(path)
 check(r.ready,"fresh v2 repository ready")
 check(r.apply("spawn_visit",["guest-01","cappuccino"]),"spawn committed")
 for station in range(3):
  for n in range(r.session.cup.targets[station]):check(r.apply("tap",[station]),"tap committed")
 r.apply("take_cup")
 var before=r.session.snapshot();var disk=r.store
 r.store=FailedStore.new()
 check(not r.apply("deliver",[r.session.data.cup_id,r.session.data.visits[0].id]),"delivery write failure reported")
 check(r.session.snapshot()==before,"entire delivery rolls back cup, profile, L, streak, payment and IDs")
 check(r.session.cup.carrying,"in-memory rollback retains the carried cup for direct retry")
 check(not r.set_preference("muted",true) and r.session.snapshot()==before and r.session.cup.carrying,"preference write rollback retains cup and settings")
 check(Repo.new(path).session.snapshot()==before,"actual reload sees pre-delivery data")
 var rng_before=r.session.snapshot()
 check(not r.apply("spawn_visit") and r.session.snapshot()==rng_before,"failed spawn rolls back RNG and visit IDs")
 r.store=disk
 var retried=r.apply("deliver",[r.session.data.cup_id,r.session.data.visits[0].id])
 check(retried,"retry delivery committed once without another pickup")
 if not retried:quit(1);return
 var id=r.session.data.payments[0].id
 before=r.session.snapshot();r.store=FailedStore.new()
 check(not r.apply("collect",[id]) and r.session.snapshot()==before,"collection write failure rolls back wallet/status")
 r.store=disk
 check(r.apply("collect",[id]) and r.session.data.money==80,"successful retry pays exactly once")
 var loaded=Repo.new(path)
 check(loaded.ready and not loaded.apply("collect",[id]) and loaded.session.data.money==80,"process reconstruction cannot duplicate collection")
 check(loaded.apply("spawn_visit",["guest-02","latte"]),"second waiting visit")
 loaded.apply("tap",[2]);loaded.apply("take_cup")
 loaded.store=FailedStore.new();before=loaded.session.snapshot()
 loaded.advance(75)
 check(loaded.session.snapshot()==before,"time transition failure rolls back all leave/expiry changes")
 check(loaded.session.cup.carrying,"time-transition rollback retains transient carry in memory")
 loaded.store=disk;loaded.advance(75)
 check(Repo.new(path).session.data.visits[1].state=="DEPARTING","terminal state checkpoint persists immediately")
 var clock=loaded.session.data.clock
 loaded.advance(300,true)
 check(loaded.session.data.clock==clock,"pause does not advance persisted clock")
 var peer_path=path+"-peers";var a=Repo.new(peer_path)
 a.apply("spawn_visit",["guest-01","cappuccino"])
 for station in range(3):
  for n in range(a.session.cup.targets[station]):a.apply("tap",[station])
 a.apply("take_cup");a.apply("deliver",[a.session.data.cup_id,a.session.data.visits[0].id])
 var b=Repo.new(peer_path);var payment=a.session.data.payments[0].id
 a.apply("collect",[payment]);b.advance(12)
 check(Repo.new(peer_path).session.data.money==80 and b.error=="STALE_WRITE","stale repository cannot replace collected wallet with expired payment")
 check(b.reload() and b.session.data.money==80 and not b.apply("collect",[payment]),"explicit reload resolves stale generation without replaying payment")
 var paused=Repo.new(path+"-pause");paused.apply("tap",[2]);paused.advance(0.75);paused.advance(0,true)
 check(Repo.new(path+"-pause").session.data.clock==0.75,"pause checkpoints fractional active time before background")
 if failures==0:print("PASS: transaction rollback, RNG/IDs, delivery/collection, real disk reload, terminal checkpoints and pause")
 quit(0 if failures==0 else 1)
