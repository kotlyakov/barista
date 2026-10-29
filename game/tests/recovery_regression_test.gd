extends SceneTree
func _init() -> void:
 var path="user://regression-corrupt-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
 for index in range(2):
  var file=FileAccess.open(path+"/slot"+str(index)+".json",FileAccess.WRITE)
  file.store_string("corrupt-"+str(index));file.close()
 var script=load("res://persistence/repository.gd")
 var repo=script.new(path)
 if repo.ready or repo.checkpoint():
  push_error("FAIL: background checkpoint must not replace corrupt saves before explicit reset")
  quit(1)
  return
 for index in range(2):
  if FileAccess.get_file_as_string(path+"/slot"+str(index)+".json")!="corrupt-"+str(index):
   push_error("FAIL: corrupt evidence overwritten")
   quit(1)
   return
 if script.new(path).ready:
  push_error("FAIL: relaunch silently reset corrupt profile")
  quit(1)
  return
 if not repo.restart() or not repo.ready:
  push_error("FAIL: explicit reset should create valid career")
  quit(1)
  return
 print("PASS: corrupted profile survives background/relaunch until explicit reset")
 quit(0)
