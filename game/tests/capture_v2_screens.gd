extends SceneTree
var node
var directory="/tmp/barista-v2-captures"
func _init():call_deferred("run")
func capture(name: String):
 node.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();assert(img!=null and not img.is_empty());assert(img.save_png(directory+"/"+name+".png")==OK)
func run():
 var args=OS.get_cmdline_user_args();if not args.is_empty():directory=args[0]
 DirAccess.make_dir_recursive_absolute(directory);root.size=Vector2i(1600,900)
 node=load("res://ui/main_v2.tscn").instantiate();node.save_directory="user://capture-v2-"+str(Time.get_ticks_usec());root.add_child(node);node.set_process(false)
 await capture("v2-01-intro");node.finish_intro();await capture("v2-02-offers")
 node.shop_tab=1;await capture("v2-03-equipment");node.shop_tab=2;await capture("v2-04-modules");node.shop_tab=3;await capture("v2-05-regulars")
 node.act("start_shift",[1]);node.screen=""
 for id in node.NAMES:
  if node.game.data.visits.size()<5:node.act("spawn_visit",[id,""])
 node.sync_guest(true);node.act("tap",[2]);await capture("v2-06-five-guests")
 for station in range(3):
  for n in range(node.game.cup.targets[station]-node.game.cup.taps[station]):node.act("tap",[station])
 node.bar_progress=[1.0,1.0,1.0];node.act("take_cup");node.dragging=true;node.cup_position=Vector2(1005,450);await capture("v2-07-drag")
 node.act("deliver",[node.game.data.cup_id,node.game.data.visits[0].id]);node.dragging=false;node.cup_position=node.CUP_HOME;node.sync_guest(true);await capture("v2-08-payment")
 node.open_menu();await capture("v2-09-menu");node.screen="progress";await capture("v2-10-progress")
 node.resume_game();node.repository.advance(400);node._process(0);await capture("v2-11-summary")
 node.queue_free();await process_frame;print("PASS: rendered11 actual Service v2 UI states");quit()
