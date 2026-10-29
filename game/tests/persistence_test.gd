extends SceneTree
const Session=preload("res://orders/session.gd")
func fill(g) -> void:
 for index in range(g.brew.targets.size()):
  for n in range(g.brew.targets[index]): g.tap(index)
func _init() -> void:
 var script=load("res://persistence/store.gd")
 if script==null:
  push_error("FAIL: native save store missing")
  quit(1)
  return
 var path="user://test-save-"+str(Time.get_ticks_usec())
 var store=script.new(path)
 var g=Session.new()
 fill(g);g.take_cup();g.deliver(g.data.order.id,"guest-01")
 assert(store.save(g.snapshot()).ok)
 var loaded=store.read_latest()
 assert(loaded.ok)
 var restored=Session.restore(loaded.snapshot)
 assert(restored.data.profiles["guest-01"].mood=="happy")
 restored.data.profiles["guest-02"].mood="annoyed"
 restored.data.profiles["guest-02"].last_reaction="Горчит"
 var relation=restored.data.profiles["guest-01"].relationship
 assert(not restored.deliver(restored.data.order.id,"guest-01"))
 assert(restored.data.profiles["guest-01"].relationship==relation)
 assert(restored.collect(restored.data.order.payment.id))
 assert(store.save(restored.snapshot()).ok)
 var paid=Session.restore(store.read_latest().snapshot)
 assert(paid.data.profiles["guest-02"].mood=="annoyed" and paid.data.profiles["guest-02"].last_reaction=="Горчит")
 assert(paid.data.money==80 and not paid.collect(paid.data.order.payment.id))
 assert(store.save(paid.snapshot()).ok)
 var file=FileAccess.open(path+"/slot0.json",FileAccess.WRITE)
 file.store_string("broken");file.close()
 loaded=store.read_latest()
 assert(loaded.ok and loaded.recovered)
 assert(loaded.snapshot.money==80,"reserve contains committed payment")
 file=FileAccess.open(path+"/slot1.json",FileAccess.WRITE)
 file.store_string("broken");file.close()
 loaded=store.read_latest()
 assert(not loaded.ok and loaded.error=="CORRUPT","no silent reset when both corrupt")
 var invalid=g.snapshot();invalid.money=-1
 assert(not store.save(invalid).ok)
 invalid=g.snapshot();invalid.order.payment.amount=9999999
 assert(not store.save(invalid).ok,"bad payout rejected")
 var blocked=script.new("/proc")
 assert(not blocked.save(g.snapshot()).ok)
 print("PASS: native snapshot, independent moods, duplicate payment after restart, damaged copy recovery, corruption/IO errors")
 quit(0)
