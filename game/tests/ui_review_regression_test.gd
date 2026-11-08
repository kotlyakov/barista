extends SceneTree
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func input_touch(node,point: Vector2,pressed: bool,index=0,canceled=false):
 var e=InputEventScreenTouch.new();e.position=point;e.index=index;e.pressed=pressed;e.canceled=canceled;node._input(e)
func tap(node,point):input_touch(node,point,true);input_touch(node,point,false)
func _init():call_deferred("run")
func run():
 var scene=load("res://ui/main_v2.tscn");var node=scene.instantiate();node.save_directory="user://ui-review-"+str(Time.get_ticks_usec());root.add_child(node);node.set_process(false);node.finish_intro()
 node.game.data.money=5000;node.repository.checkpoint();tap(node,node.tab_rect(1).get_center());var gear=node.gear_rect(0).get_center()
 input_touch(node,gear,true,0);input_touch(node,gear,true,1);input_touch(node,gear,false,1);input_touch(node,gear,false,0)
 check(node.game.data.upgrades.grind==1 and node.game.data.money==4600,"simultaneous second finger cannot buy another level")
 tap(node,node.START_BUTTON.get_center());node._process(.35);node.finish_intro();node._process(2.5);node._process(0);var visit=node.game.data.visits[0]
 check(absf(visit.bubble_until-node.game.data.clock-3)<0.0001,"first wish gets3 full active seconds at counter")
 node._process(4);var before=visit.bubble_until;var point=node.visit_drop_rect(visit.id).get_center()
 input_touch(node,point,true);input_touch(node,point,false,0,true)
 check(visit.bubble_until==before,"canceled gesture never reminds wish")
 node._process(0.5);before=visit.bubble_until;input_touch(node,point,true)
 var drag=InputEventScreenDrag.new();drag.index=0;drag.position=point+Vector2(50,0);node._input(drag);input_touch(node,drag.position,false)
 check(visit.bubble_until==before,"drag across guest never reminds wish")
 tap(node,node.station_rects[1].get_center())
 check(node.game.cup.taps[1]==0 and str(node.get("speech_text"))=="Ой! Зёрна-то не помолола!","brew refusal has required spoken feedback")
 check(float(node.get("facepalm_until") if node.get("facepalm_until")!=null else -1)>node.game.data.clock,"brew refusal starts existing-hand facepalm")
 node.speech_text="";node.speech_until=-1
 tap(node,node.CARTON_RECT.get_center());tap(node,node.station_rects[2].get_center())
 tap(node,Vector2(762,793))
 check(node.game.cup.milk_doses==1 and not node.dragging,"former discard icon has no hit target")
 input_touch(node,node.V2_CUP_HOME,true)
 check(node.dragging and node.speech_text=="" and node.speech_until==-1,"raw pickup stays silent")
 input_touch(node,Vector2(200,200),false);node.act("take_cup");node.act("deliver",[node.game.data.cup_id,visit.id])
 tap(node,node.station_rects[0].get_center());tap(node,node.station_rects[1].get_center())
 check(node.game.cup.contents()=="espresso" and node.has_method("current_cup_label") and node.call("current_cup_label")=="Эспрессо","actual espresso is never labelled intended latte")
 var guest_id=""
 for id in node.GUEST_IDS:
  if id!=visit.customer_id:guest_id=id;break
 node.act("spawn_visit",[guest_id,"latte"]);node.sync_guest(true);var receiver=node.game.data.visits.back()
 for station in [0,1]:
  for n in range(node.game.cup.targets[station]-node.game.cup.taps[station]):node.act("tap",[station])
 node.act("take_cup");node.act("deliver",[node.game.data.cup_id,receiver.id]);node.sync_guest(true)
 check(node.rigs[receiver.id].cup_recipe=="espresso","recipient holds actual delivered espresso,not wished latte")
 check(node.visit_speech(receiver)!="","stationary guest has a timed reaction")
 var actor=node.rigs[receiver.id]
 for phase in ["enter","turn","leave"]:
  actor.phase=phase
  check(node.visit_speech(receiver)=="","moving guest cannot speak: "+phase)
 actor.phase="idle"
 check(node.act("collect",[receiver.payment_id]),"reaction scenario collects its own payment")
 node.sync_guest()
 check(actor.phase=="wait_leave" and node.visit_speech(receiver)!="","collecting does not cut off a stationary reaction")
 node.repository.advance(4)
 check(node.visit_speech(receiver)=="","reaction expires after three active seconds")
 for step in range(8):
  if actor.phase in ["turn","leave"]:break
  node._process(.6)
 check(actor.phase in ["turn","leave"],"guest leaves once the reaction ends and corridor is free")
 for n in range(node.game.cup.targets[0]-1):node.act("tap",[0])
 check(node.operation_color(0)==node.STATION_COLORS[0],"ordinary taps keep their station color")
 node.act("tap",[0])
 check(node.operation_color(0)==node.PERFECT_COLOR,"exact target is bright green")
 node.act("tap",[0])
 var first_over: Color=node.operation_color(0)
 check(first_over.g>first_over.r and first_over!=node.PERFECT_COLOR,"first extra tap only warms the green")
 for n in range(9):node.act("tap",[0])
 check(node.operation_color(0)==node.OVERTAP_COLOR,"ten extra taps reach red")
 node.open_menu();tap(node,node.MENU_DISCARD.get_center())
 check(node.game.cup.is_empty() and not node.paused,"pause action empties the cup and returns to play")
 node.queue_free();await process_frame
 var path="user://ui-legacy-error-"+str(Time.get_ticks_usec());var B=load("res://ui/session_bridge.gd");var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/payment.json"));B.V2.LegacyStore.new(path).save(old)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path+"/v2-candidate"));var f=FileAccess.open(path+"/v2-candidate/slot0.json",FileAccess.WRITE);f.store_string("corrupt");f.close()
 node=scene.instantiate();node.save_directory=path;root.add_child(node);node.set_process(false);node.finish_intro();node.act("collect",[node.game.data.order.id]);node.repository.try_migrate()
 var bytes=FileAccess.get_file_as_bytes(path+"/slot0.json");node.open_menu()
 check(not node.repository.ready and node.screen=="error","legacy migration failure uses non-destructive common error UI")
 check(FileAccess.get_file_as_bytes(path+"/slot0.json")==bytes,"error UI performs no extra legacy writes")
 if node.screen=="error":tap(node,node.MENU_RESUME.get_center());tap(node,node.MENU_RESUME.get_center())
 node.queue_free();await process_frame
 if failures==0:print("PASS: review regressions for two-touch purchases,cancel/drag reminder,visible wish timing,speech/facepalm,actual contents,timed reactions,over-tap colors and legacy failure screen")
 quit(0 if failures==0 else 1)
