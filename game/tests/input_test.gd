extends SceneTree
func _init() -> void:
 var script=load("res://ui/pointer_gate.gd")
 if script==null:
  push_error("FAIL: single pointer input gate missing")
  quit(1)
  return
 var gate=script.new()
 var t=InputEventScreenTouch.new()
 t.index=0;t.pressed=true;t.position=Vector2(10,10)
 assert(gate.route(t).action=="press")
 assert(gate.route(t).is_empty(),"held event cannot repeat")
 var second=InputEventScreenTouch.new()
 second.index=1;second.pressed=true
 assert(gate.route(second).is_empty(),"second finger ignored")
 var mouse=InputEventMouseButton.new()
 mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.device=InputEvent.DEVICE_ID_EMULATION
 assert(gate.route(mouse).is_empty(),"synthetic mouse ignored")
 t.pressed=false
 assert(gate.route(t).action=="release")
 t.pressed=true
 assert(gate.route(t,true).is_empty(),"pause rejects input")
 gate.cancel()
 assert(gate.route(t).action=="press")
 gate.cancel()
 mouse.device=0
 assert(gate.route(mouse).action=="press","real mouse works on desktop")
 print("PASS: single pointer, hold, secondary touch, emulated mouse, pause, cancel")
 quit(0)
