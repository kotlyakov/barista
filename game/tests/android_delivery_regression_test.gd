extends SceneTree
const Service=preload("res://orders/service.gd")
const Repo=preload("res://persistence/repository_v2.gd")
const Schema=preload("res://persistence/service_schema.gd")
func touch(node,point: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed;node._input(event)
func require_ok(condition: bool,message: String) -> bool:
 if not condition:push_error(message);quit(1);return false
 return true
func _init():call_deferred("run")
func run():
 var snapshot=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2/android_drop.json"))
 if not require_ok(Schema.valid(snapshot),"Android pre-delivery snapshot must be valid"):return
 var direct=Service.restore(snapshot)
 if not require_ok(direct.take_cup(),"Take captured cup failed"):return
 if not require_ok(direct.deliver(1,2),"Domain rejected valid actual Android delivery"):return
 if not require_ok(Schema.valid(direct.snapshot()),"Delivery produced an invalid snapshot"):return
 var directory="user://android-drop-regression-"+str(Time.get_ticks_usec())
 var repo=Repo.new(directory);repo.session=Service.restore(snapshot)
 if not require_ok(repo.checkpoint(),"Setup checkpoint failed: "+repo.error):return
 if not require_ok(repo.apply("take_cup"),"Repository take failed: "+repo.error):return
 var accepted=repo.apply("deliver",[1,2])
 print("REPOSITORY_DELIVERY accepted=",accepted," error=",repo.error)
 if not require_ok(accepted,"Actual Android snapshot must survive transactional delivery: "+repo.error):return
 var node=load("res://ui/main_v2.tscn").instantiate();node.save_directory=directory+"-ui";root.add_child(node);node.set_process(false)
 node.repository.backend.session=Service.restore(snapshot);node.game=node.repository.session
 if not require_ok(node.repository.checkpoint(),"UI setup checkpoint failed: "+node.repository.error):return
 node.finish_intro();node.sync_guest(true)
 touch(node,node.V2_CUP_HOME,true)
 var move=InputEventScreenDrag.new();move.index=0;move.position=node.visit_drop_rect(2).get_center();node._input(move)
 touch(node,move.position,false)
 print("UI_DELIVERY payments=",node.game.data.payments.size()," error=",node.repository.error)
 if not require_ok(node.game.data.payments.size()==1,"Exact Android drag must create one payment: "+node.repository.error):return
 node.queue_free();await process_frame
 print("PASS: captured Android delivery through domain,transaction and exact UI drag")
 quit()
