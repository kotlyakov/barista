extends SceneTree
func touch(node,point: Vector2) -> void:
 var event=InputEventScreenTouch.new()
 event.index=0;event.position=point;event.pressed=true;node._input(event)
 event.pressed=false;node._input(event)
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var node=load("res://ui/main.tscn").instantiate()
 assert(node.get("audio_safe_start")!=null,"diagnostic build needs a safe audio startup")
 node.audio_safe_start=true
 var path="user://audio-diagnostics-"+str(Time.get_ticks_usec())
 node.save_directory=path
 root.add_child(node)
 node.set_process(false)
 node.finish_intro()
 assert(node.audio.muted,"safe startup must block audio even for a previously unmuted profile")
 assert(not node.repository.preferences().muted,"temporary mitigation must not overwrite saved preference")
 node.audio.trace("before test native call")
 var money=node.game.data.money
 node.open_menu()
 touch(node,Vector2(800,525))
 assert(not node.audio.muted,"explicit sound enable must still be available for diagnosis")
 assert(node.game.data.money==money,"diagnostics must not change career balance")
 node.queue_free()
 await process_frame
 var next=load("res://ui/main.tscn").instantiate()
 next.audio_safe_start=true
 next.save_directory=path
 root.add_child(next)
 next.set_process(false)
 next.finish_intro()
 assert(next.audio.muted,"restart must return to safe audio even after enabling it")
 assert(next.audio.report().contains("before test native call"),"previous process breadcrumbs must survive restart")
 next.queue_free()
 await process_frame
 print("PASS: safe audio startup, explicit opt-in and previous-run diagnostic recovery")
 quit()
