extends SceneTree
func _init() -> void:
 var rig_script=load("res://ui/cafe_actor.gd")
 if rig_script==null:
  push_error("FAIL: cafe actor missing")
  quit(1)
  return
 var rig=rig_script.new()
 rig.enter("beard",false)
 rig.step(3)
 assert(rig.phase=="idle")
 rig.depart()
 var start=rig.position
 rig.step(.15)
 assert(rig.position.is_equal_approx(start),"turn before moving away")
 rig.step(.3)
 assert(rig.facing>0,"departing guest faces toward exit")
 rig.step(3)
 assert(rig.phase=="gone")
 rig.free()
 print("PASS: guest turns before departure, faces exit, then clears queue slot")
 quit()
