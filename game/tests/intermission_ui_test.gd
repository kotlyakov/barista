extends SceneTree
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func tap(node,point: Vector2):
 var e=InputEventScreenTouch.new();e.position=point;e.pressed=true;node._input(e);e.pressed=false;node._input(e)
func _init():call_deferred("run")
func run():
 var node=load("res://ui/main_v2.tscn").instantiate();node.save_directory="user://intermission-ui-"+str(Time.get_ticks_usec());root.add_child(node);node.set_process(false);node.finish_intro()
 node.game.data.money=10000;node.repository.checkpoint();var original=node.game.data.money
 tap(node,node.offer_rect(0).get_center());var purchased=node.game.data.economy.choice
 check(purchased!="" and node.game.data.money<original,"real offer touch spends once")
 var wallet=node.game.data.money;tap(node,node.offer_rect(1).get_center());check(node.game.data.money==wallet and node.game.data.economy.choice==purchased,"second offer touch cannot spend")
 tap(node,node.tab_rect(1).get_center());tap(node,node.gear_rect(0).get_center());check(node.game.data.upgrades.grind==1,"equipment page actual purchase")
 tap(node,node.EXTRA_BUTTON.get_center());tap(node,node.offer_rect(0).get_center());tap(node,node.offer_rect(0).get_center());tap(node,Vector2(500,660))
 check(node.game.data.economy.equipped_modules[0]=="heat","module buy/select/slot actions")
 tap(node,node.tab_rect(4).get_center());tap(node,node.regular_rect(0).position+Vector2(140,120))
 check(node.game.data.economy.gifts["guest-01"],"gift reservation touch saved")
 var reload=node.Bridge.new(node.save_directory);check(reload.session.data.economy.equipped_modules[0]=="heat" and reload.session.data.economy.gifts["guest-01"],"intermission decisions survive actual reload")
 tap(node,node.START_BUTTON.get_center());check(node.game.data.shift.phase=="RUNNING","start after purchases");node.finish_intro()
 node.open_menu();node.screen="progress";var before=node.game.snapshot();tap(node,node.LESSON_BUTTON.get_center())
 check(node.repository.training and node.screen=="lesson","menu lesson uses new Service")
 tap(node,node.station_rects[2].get_center());node._process(0.5);node.finish_lesson()
 check(node.game.snapshot()==before,"UI lesson leaves career money/history/RNG/clock unchanged")
 node.resume_game();node.repository.advance(400);node._process(0);check(node.screen=="between" and node.game.data.shift.phase=="SUMMARY","real summary window")
 tap(node,node.NEXT_BUTTON.get_center());check(node.game.data.shift.day_number==2 and node.game.data.economy.choice=="","next day resets one-day decision")
 node.queue_free();await process_frame
 if failures==0:print("PASS: actual intermission offer/equipment/module/gift touches,reload,isolated lesson,summary and next day")
 quit(0 if failures==0 else 1)
