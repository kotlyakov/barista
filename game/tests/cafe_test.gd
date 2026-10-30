extends SceneTree
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var node=load("res://ui/main.tscn").instantiate()
 node.career_enabled=false
 node.save_directory="user://cafe-test-"+str(Time.get_ticks_usec())
 root.add_child(node)
 await process_frame
 assert(node.station_rects[0].has_point(Vector2(150,700)),"grinder zone must match approved art")
 assert(node.station_rects[1].has_point(Vector2(530,520)),"brewer zone must match approved art")
 assert(node.station_rects[2].has_point(Vector2(850,400)),"milk zone must match approved art")
 assert(node.has_method("draw_cafe"),"native cafe compositor required")
 node.queue_free()
 print("PASS: approved cafe appliance coordinates and compositor")
 quit()
