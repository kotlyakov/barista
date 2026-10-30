extends SceneTree
func touch(node,point: Vector2) -> void:
 var e=InputEventScreenTouch.new()
 e.index=0;e.position=point;e.pressed=true;node._input(e)
 e.pressed=false;node._input(e)
func _init() -> void: call_deferred("run")
func run() -> void:
 var path="user://recovery-ui-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
 for i in range(2):
  var file=FileAccess.open(path+"/slot"+str(i)+".json",FileAccess.WRITE)
  file.store_string("broken");file.close()
 var node=load("res://ui/main.tscn").instantiate()
 node.save_directory=path
 root.add_child(node)
 node.set_process(false)
 node.finish_intro()
 node.open_menu()
 touch(node,Vector2(800,425))
 assert(not node.repository.ready,"first reset touch only asks for explicit confirmation")
 assert(FileAccess.get_file_as_string(path+"/slot0.json")=="broken")
 touch(node,Vector2(800,425))
 assert(node.repository.ready,"confirmed reset must recover playable profile")
 assert(node.screen=="" and not node.paused)
 node.queue_free()
 await process_frame
 print("PASS: damaged saves preserved until explicit two-step UI reset")
 quit()
