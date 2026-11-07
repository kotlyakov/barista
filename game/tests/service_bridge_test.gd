extends SceneTree
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func _init():
 if not ResourceLoader.exists("res://ui/session_bridge.gd"):print("FAIL: UI session bridge absent");quit(1);return
 var B=load("res://ui/session_bridge.gd");var path="user://bridge-"+str(Time.get_ticks_usec());var b=B.new(path)
 check(b.ready and not b.legacy and b.session.data.has("economy"),"fresh game initializes new career")
 check(b.apply("start_shift",[1]),"start through bridge")
 b.advance(0.375);b.suspend();var before=b.session.snapshot()
 check(B.new(path).session.snapshot()==before,"fractional background save")
 check(b.begin_lesson(),"isolated new model lesson")
 b.apply("tap",[2]);b.advance(50);b.end_training()
 check(b.session.snapshot()==before,"training leaves main wallet/history/RNG/clock unchanged")
 var old_path=path+"old";var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/running.json"));B.V2.LegacyStore.new(old_path).save(old)
 var legacy=B.new(old_path);check(legacy.ready and legacy.legacy,"old active session continues")
 legacy.advance(0.25);check(legacy.session.shift.data.mode=="RUNNING","actual calendar does not prematurely close legacy")
 var boundary_path=path+"boundary";old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/summary.json"));B.V2.LegacyStore.new(boundary_path).save(old)
 var migrated=B.new(boundary_path)
 check(migrated.ready and not migrated.legacy and migrated.session.data.money==4777,"safe old boundary auto-activates approved policy once")
 check(B.new(boundary_path).session.data.money==4777,"UI restart does not repeat compensation")
 var damaged=path+"damaged";B.V2.LegacyStore.new(damaged).save(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/running.json")))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(damaged+"/v2"))
 var file=FileAccess.open(damaged+"/v2/slot0.json",FileAccess.WRITE);file.store_string("{corrupt");file.close()
 var rejected=B.new(damaged)
 check(not rejected.ready and not rejected.legacy,"damaged newer profile cannot fall back to older active legacy")
 if failures==0:print("PASS: UI bridge fresh/restart/background,isolated lesson,legacy calendar and approved one-time activation")
 quit(0 if failures==0 else 1)
