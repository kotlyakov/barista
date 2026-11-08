extends SceneTree

func _init() -> void:
 call_deferred("run")

func tap(node, point: Vector2) -> void:
 var event = InputEventScreenTouch.new()
 event.position = point
 event.pressed = true
 node._input(event)
 event.pressed = false
 node._input(event)

func run() -> void:
 var node = load("res://ui/main_v2.tscn").instantiate()
 node.save_directory = "user://charcoal-layout-" + str(Time.get_ticks_usec())
 root.add_child(node)
 node.set_process(false)
 node.finish_intro()
 var failures: Array[String] = []
 tap(node, Vector2(1270, 192))
 if node.shop_tab != 2:
  failures.append("The right-hand tab must open Passives.")
 tap(node, Vector2(1320, 820))
 node._process(.35)
 node.finish_intro()
 if node.game.data.shift.phase != "RUNNING":
  failures.append("Start Shift must work at the approved button position.")
 node.finish_intro()
 tap(node, Vector2(900, 754))
 if node.game.cup.taps[0] != 1:
  failures.append("The grinder on the right must accept a tap.")
 tap(node, node.CARTON_RECT.get_center())
 tap(node, Vector2(1100, 754))
 if node.game.cup.taps[2] != 1:
  failures.append("The center appliance must be the steamer.")
 tap(node, Vector2(1380, 754))
 if node.game.cup.taps[1] != 1:
  failures.append("The right-most appliance must be the brewer.")
 node.queue_free()
 await process_frame
 for failure in failures:
  push_error(failure)
 if failures.is_empty():
  print("PASS: three approved tab and appliance touch positions")
 quit(0 if failures.is_empty() else 1)
