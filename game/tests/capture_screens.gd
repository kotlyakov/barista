extends SceneTree
var node
var directory="/tmp/barista-native-captures"
func _init() -> void:
 call_deferred("run")
func capture(name: String) -> void:
 node.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 assert(image!=null and not image.is_empty())
 assert(image.save_png(directory+"/"+name+".png")==OK)
func run() -> void:
 var args=OS.get_cmdline_user_args()
 if not args.is_empty(): directory=args[0]
 DirAccess.make_dir_recursive_absolute(directory)
 root.size=Vector2i(1600,900)
 node=load("res://ui/main.tscn").instantiate()
 node.save_directory="user://capture-"+str(Time.get_ticks_usec())
 root.add_child(node)
 node.set_process(false)
 await capture("01-intro-dark")
 node._process(1.5)
 await capture("02-intro-entry")
 node._process(1.5)
 await capture("03-cafe-before-opening")
 node.act("choose_perk",[node.game.shift.data.offers[0]])
 node.act("start_shift")
 node.sync_guest()
 node.guest.step(3)
 for i in range(3):
  for j in range(node.game.brew.targets[i]): node.act("tap",[i])
 node.bar_progress=[1.0,1.0,1.0]
 await capture("04-cafe-cup")
 node.act("take_cup")
 node.act("deliver",[node.game.data.order.id,node.game.data.order.customer_id])
 node.sync_guest()
 await capture("05-cafe-payment")
 node.open_menu()
 await capture("06-menu")
 node.screen="progress"
 await capture("07-progress-no-people")
 node.queue_free()
 await process_frame
 print("PASS: rendered 7 native single-cafe states")
 quit()
