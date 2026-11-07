extends SceneTree
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func touch(node,point: Vector2,index=0):
 var e=InputEventScreenTouch.new();e.index=index;e.position=point;e.pressed=true;node._input(e)
 e.pressed=false;node._input(e)
func press(node,point: Vector2):
 var e=InputEventScreenTouch.new();e.position=point;e.pressed=true;node._input(e)
func release(node,point: Vector2):
 var e=InputEventScreenTouch.new();e.position=point;e.pressed=false;node._input(e)
func _init():call_deferred("run")
func run():
 if not ResourceLoader.exists("res://ui/main_v2.tscn"):print("FAIL: new UI scene absent");quit(1);return
 var node=load("res://ui/main_v2.tscn").instantiate();node.save_directory="user://free-ui-"+str(Time.get_ticks_usec());root.add_child(node);node.set_process(false);node.finish_intro()
 check(node.game.data.shift.phase=="PREPARING","new UI opens preparation")
 touch(node,node.START_BUTTON.get_center());check(node.game.data.shift.phase=="RUNNING","real start touch")
 touch(node,node.station_rects[2].get_center());check(node.game.cup.taps[2]==1 and not node.game.cup.is_empty(),"milk-first free cup")
 press(node,node.CUP_HOME);release(node,Vector2(300,200));check(not node.game.cup.carrying and node.game.cup.taps[2]==1,"miss returns same unfinished cup")
 touch(node,node.station_rects[0].get_center());check(node.game.cup.taps[0]==1,"continue preparation after miss")
 press(node,node.CUP_HOME);node.open_menu();check(not node.game.cup.carrying and not node.dragging,"menu cancels gesture without cup loss")
 var before=node.game.snapshot();node._process(1);check(node.game.snapshot()==before,"menu pauses actual active time")
 node.resume_game();var v=node.game.data.visits[0];node.act("select_recipe",[v.wish_recipe]) # occupied cup cannot switch
 for station in range(3):
  var needed=node.game.cup.targets[station]-node.game.cup.taps[station]
  for i in range(needed):touch(node,node.station_rects[station].get_center())
 node.sync_guest(true)
 press(node,node.CUP_HOME);release(node,node.visit_drop_rect(v.id).get_center())
 check(node.game.data.payments.size()==1,"actual visitor receives prepared cup")
 var p=node.game.data.payments[0];touch(node,node.visit_coin_rect(v.id).get_center());check(p.state=="COLLECTED" and node.game.data.money==p.amount,"touch coins once")
 var wallet=node.game.data.money;touch(node,node.visit_coin_rect(v.id).get_center());check(node.game.data.money==wallet,"no repeat payment")
 touch(node,node.station_rects[0].get_center());press(node,node.CUP_HOME)
 var canceled=InputEventScreenTouch.new();canceled.canceled=true;canceled.index=0;node._input(canceled)
 check(not node.dragging and not node.game.cup.carrying,"platform cancel returns cup")
 var taps=node.game.cup.taps[0];press(node,node.station_rects[0].get_center());touch(node,node.station_rects[0].get_center(),1);release(node,node.station_rects[0].get_center());check(node.game.cup.taps[0]==taps+1,"second finger cannot double tap")
 node._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);check(node.paused and not node.game.cup.carrying,"background pauses and saves")
 var restored=node.Bridge.new(node.save_directory)
 check(JSON.parse_string(JSON.stringify(restored.session.snapshot()))==JSON.parse_string(JSON.stringify(node.game.snapshot())),"restart restores same numeric gameplay state")
 node.queue_free();await process_frame
 if failures==0:print("PASS: actual new UI start,milk-first,miss/rework,menu/background/restart,free delivery/coins,cancel and second finger")
 quit(0 if failures==0 else 1)
