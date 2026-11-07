extends SceneTree

func _init() -> void:
 call_deferred("run")

func run() -> void:
 var scene=load("res://ui/main_v2.tscn")
 var node=scene.instantiate()
 node.save_directory="user://intro-transition-"+str(Time.get_ticks_usec())
 root.add_child(node)
 node.set_process(false)
 node.shop_input(node.START_BUTTON.get_center())
 if node.screen!="fold" or node.game.data.shift.phase!="PREPARING":
  push_error("The leaf must fold before starting the shift");quit(1);return
 node._process(0.35)
 node._process(2.0)
 if node.screen!="intro" or not node.game.data.visits.is_empty() or node.game.data.clock!=0:
  push_error("Intro advanced visits or clock");quit(1);return
 var event=InputEventScreenTouch.new()
 event.position=node.station_rects[0].get_center()
 event.pressed=true
 node._input(event)
 event.pressed=false
 node._input(event)
 if node.game.data.shift.phase!="RUNNING" or node.game.data.visits.size()!=1 or node.game.cup.taps[0]!=0:
  push_error("Skipping intro must start one visit without operating the grinder");quit(1);return
 var path=node.save_directory
 node.queue_free()
 await process_frame
 var resumed=scene.instantiate()
 resumed.save_directory=path
 root.add_child(resumed)
 resumed.set_process(false)
 if resumed.screen!="" or resumed.game.data.visits.size()!=1:
  push_error("Resuming must preserve the visit without replaying the intro");quit(1);return
 resumed.queue_free()
 await process_frame
 print("PASS: folding, first-person intro, input consumption and resume")
 quit()
