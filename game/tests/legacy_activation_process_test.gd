extends SceneTree
const R=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func _init():
 if not R.new("user://activation-process-missing-"+str(Time.get_ticks_usec())).has_method("activate_legacy_candidate"):print("FAIL: process-safe activation absent");quit(1);return
 var args=OS.get_cmdline_user_args()
 if args.size()==2:probe(args[0],args[1]);return
 var path="user://activation-process-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 for phase in ["stage","publish","spend","verify"]:
  var output=[]
  var code=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/legacy_activation_process_test.gd","--",phase,path],output,true)
  check(code==0 and not "ERROR:" in "\n".join(output) and "PASS:" in "\n".join(output),"actual separate activation process "+phase+" "+"\n".join(output))
 if failures==0:print("PASS: four actual stage/publication/purchase/retry processes without repeated migration credits")
 quit(0 if failures==0 else 1)
func probe(phase: String,path: String):
 if phase=="stage":
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/summary.json"));R.LegacyStore.new(path).save(old)
 var r=R.new(path)
 if phase=="stage":
  var c=r.prepare_legacy_candidate();check(c.ok,"candidate prepared")
  c.snapshot.migration.candidate_only=false
  check(R.Store.new(path+"/v2-activate").save(c.snapshot,0).ok,"first staged slot survives process exit")
 else:
  var hash=R.Store.new(path+"/v2-candidate").read_latest().snapshot.migration.source_hash
  if phase=="publish":check(not r.ready and r.activate_legacy_candidate(hash) and r.session.data.money==4777,"restart resumes and publishes once")
  elif phase=="spend":check(r.ready and r.apply("buy_equipment",["grind",1]) and r.session.data.money==3977,"post-migration spending")
  elif phase=="verify":check(r.ready and r.activate_legacy_candidate(hash) and r.session.data.money==3977 and r.session.data.upgrades.grind==2,"later restart cannot regrant refund or reward")
 if failures==0:print("PASS: activation process "+phase)
 quit(0 if failures==0 else 1)
