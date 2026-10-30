extends SceneTree
func touch(node,point: Vector2) -> void:
 var event=InputEventScreenTouch.new()
 event.index=0;event.pressed=true;event.position=point;node._input(event)
 event.pressed=false;node._input(event)
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var node=load("res://ui/main.tscn").instantiate()
 node.save_directory="user://screens-"+str(Time.get_ticks_usec())
 root.add_child(node)
 await process_frame
 assert(node.get("screen")=="intro","career opens directly in cafe")
 var clock=node.game.data.clock
 node._process(3)
 assert(node.game.data.clock==clock,"intro freezes active time")
 node.start_lesson()
 assert(node.screen=="lesson","isolated lesson remains available to training code")
 assert(node.repository.training)
 var main_snapshot=node.repository.main_session.snapshot()
 # Modal must consume station taps and never affect brew or economy.
 node.open_menu()
 var taps=node.game.brew.taps.duplicate()
 touch(node,node.station_rects[0].get_center())
 assert(node.game.brew.taps==taps)
 node.resume_game()
 for i in range(3):
  for j in range(node.game.brew.targets[i]):touch(node,node.station_rects[i].get_center())
 touch(node,node.CUP_HOME)
 touch(node,node.GUEST_RECT.get_center())
 touch(node,node.COIN_RECT.get_center())
 assert(node.repository.preferences().tutorial_seen)
 node.finish_lesson()
 assert(node.screen=="menu" and not node.repository.training)
 assert(node.game.data.money==main_snapshot.money)
 assert(node.game.data.rng_state==main_snapshot.rng_state)
 node.queue_free()
 print("PASS: cafe/menu input isolation, guided lesson full loop, no career rewards or RNG mutation")
 quit()
