extends SceneTree
func _init() -> void:
 var path="user://process-restart-"+str(Time.get_ticks_usec())
 for phase in ["write","resume","verify"]:
  var output=[]
  var result=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/service_process_probe.gd","--",phase,path],output,true)
  var joined="\n".join(output)
  if result!=0 or "ERROR:" in joined or not "PASS:" in joined:
   print(joined);quit(1);return
 print("PASS: separate Godot process write/background/restart/collect/restart without duplicated history or lost timer fractions")
 quit()
