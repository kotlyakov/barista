extends SceneTree
func touch(node,point: Vector2,pressed: bool) -> void:
 var event=InputEventScreenTouch.new()
 event.index=0;event.position=point;event.pressed=pressed
 node._input(event)
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var scene=load("res://ui/main.tscn")
 var node=scene.instantiate()
 var path="user://ui-flow-"+str(Time.get_ticks_usec())
 node.career_enabled=false
 node.save_directory=path
 root.add_child(node)
 await process_frame
 for index in range(3):
  for n in range(node.game.brew.targets[index]):
   var point=node.station_rects[index].get_center()
   touch(node,point,true);touch(node,point,false)
 assert(node.game.brew.ready())
 touch(node,node.CUP_HOME,true)
 touch(node,Vector2(10,800),false)
 assert(node.game.brew.locked and node.game.data.order.state=="BREWING")
 touch(node,node.cup_position,true);touch(node,node.GUEST_RECT.get_center(),false)
 assert(node.game.data.order.state=="PAYMENT")
 var restored=load("res://persistence/repository.gd").new(path)
 assert(restored.session.data.order.state=="PAYMENT")
 touch(node,node.COIN_RECT.get_center(),true);touch(node,node.COIN_RECT.get_center(),false)
 assert(node.game.data.money==80)
 restored=load("res://persistence/repository.gd").new(path)
 assert(restored.session.data.money==80)
 assert(not restored.apply("collect",[1]))
 node.queue_free()
 print("PASS: native UI touch pipeline -> brew -> missed drop -> delivery -> restart -> collection")
 quit(0)
