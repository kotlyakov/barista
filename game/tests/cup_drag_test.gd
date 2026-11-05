extends SceneTree
func touch(node,point: Vector2,pressed: bool,cancelled=false,index=0) -> void:
 var event=InputEventScreenTouch.new()
 event.index=index;event.position=point;event.pressed=pressed;event.canceled=cancelled
 node._input(event)
func move(node,point: Vector2,index=0) -> void:
 var event=InputEventScreenDrag.new()
 event.index=index;event.position=point
 node._input(event)
func _init() -> void: call_deferred("run")
func run() -> void:
 var node=load("res://ui/main.tscn").instantiate()
 node.career_enabled=false
 node.save_directory="user://cup-drag-"+str(Time.get_ticks_usec())
 root.add_child(node)
 node.set_process(false)
 for stage in range(3):
  for n in range(node.game.brew.targets[stage]): assert(node.act("tap",[stage]))
 var home=node.CUP_HOME
 var offset=Vector2(40,30)
 touch(node,home+offset,true)
 assert(node.cup_position.is_equal_approx(home),"pickup must preserve cup position, not jump to finger")
 # Finger is inside guest target, but cup centre remains left of its edge.
 var edge=Vector2(node.GUEST_RECT.position.x+20,400)
 move(node,edge)
 assert(node.cup_position.is_equal_approx(edge-offset))
 touch(node,edge,false)
 assert(node.game.data.order.state=="BREWING","drop uses cup centre rather than finger")
 node._process(1)
 touch(node,node.GUEST_RECT.get_center(),true)
 touch(node,node.GUEST_RECT.get_center(),false)
 assert(node.game.data.order.state=="BREWING","guest tap cannot serve a cup left on counter")
 touch(node,node.cup_position,true)
 move(node,node.GUEST_RECT.get_center())
 touch(node,node.GUEST_RECT.get_center(),false,true)
 assert(not node.dragging and node.game.data.order.state=="BREWING","cancelled touch never delivers")
 node._process(1)
 touch(node,node.cup_position,true)
 touch(node,node.GUEST_RECT.get_center(),true,false,1)
 touch(node,node.GUEST_RECT.get_center(),false,false,1)
 assert(node.game.data.order.state=="BREWING","second finger never releases carried cup")
 node.open_menu()
 touch(node,node.GUEST_RECT.get_center(),false)
 assert(node.game.data.order.state=="BREWING" and not node.dragging)
 node.resume_game()
 touch(node,node.cup_position,true)
 move(node,node.GUEST_RECT.get_center())
 touch(node,node.GUEST_RECT.get_center(),false)
 assert(node.game.data.order.state=="PAYMENT","fresh valid drag after pause serves once")
 node.sync_guest()
 assert(node.guest.held_cup)
 assert(node.act("collect",[node.game.data.order.id]))
 node.sync_guest()
 assert(node.guest.held_cup,"served cup remains with guest after payment collection")
 node.queue_free()
 await process_frame
 print("PASS: cup pickup offset, centre-based drop, guest tap rejection, cancelled/secondary touch and paused drag")
 quit()
