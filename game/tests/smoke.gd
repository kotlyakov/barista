extends SceneTree
func _init() -> void:
 var scene = load("res://ui/main.tscn")
 if scene == null:
  push_error("FAIL: main scene missing")
  quit(1)
  return
 var node = scene.instantiate()
 node.career_enabled=false
 node.save_directory="user://smoke-"+str(Time.get_ticks_usec())
 root.add_child(node)
 await process_frame
 print("PASS: Godot native main scene instantiates")
 node.queue_free()
 quit(0)
