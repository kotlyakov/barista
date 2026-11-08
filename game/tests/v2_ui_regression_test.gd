extends SceneTree
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func _init():call_deferred("run")
func run():
 var node=load("res://ui/main_v2.tscn").instantiate();node.save_directory="user://v2-ui-reg-"+str(Time.get_ticks_usec());root.add_child(node);node.set_process(false);node.finish_intro();node.act("start_shift",[1]);node.screen=""
 for id in node.GUEST_IDS:
  if node.game.data.visits.size()<5:node.act("spawn_visit",[id,""])
 node.sync_guest(true);check(node.slots.size()==5,"all five guests represented")
 node.repository.advance(75);var departed=node.game.data.visits[0].id;check(node.act("finish_departure",[departed]),"departure releases business slot")
 node.sync_guest(true)
 check(node.slots.size()<=5,"no stale rendered visit")
 for slot in node.slots.values():check(slot>=0 and slot<5,"reused visual slot never escapes screen")
 node.queue_free();await process_frame
 var path="user://v2-ui-corrupt-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path+"/v2"));var file=FileAccess.open(path+"/v2/slot0.json",FileAccess.WRITE);file.store_string("corrupt");file.close()
 node=load("res://ui/main_v2.tscn").instantiate();node.save_directory=path;root.add_child(node);node.set_process(false)
 check(not node.repository.ready and node.paused and node.screen=="error","corrupt profile has safe paused error screen")
 node.queue_redraw();await process_frame;check(FileAccess.get_file_as_string(path+"/v2/slot0.json")=="corrupt","UI never resets damaged profile")
 node.queue_free();await process_frame
 if failures==0:print("PASS: visual slot reuse after terminal transition and safe damaged-profile screen")
 quit(0 if failures==0 else 1)
