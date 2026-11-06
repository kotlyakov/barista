extends SceneTree
const R=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func fixture():return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/summary.json"))
func _init():
 if not R.new("user://candidate-absent-"+str(Time.get_ticks_usec())).has_method("prepare_legacy_candidate"):print("FAIL: separate candidate persistence absent");quit(1);return
 var args=OS.get_cmdline_user_args()
 if args.size()==2:probe(args[0],args[1]);return
 var path="user://candidate-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 check(R.LegacyStore.new(path).save(fixture()).ok,"write original v1")
 var original=FileAccess.get_file_as_bytes(path+"/slot0.json")
 var r=R.new(path);check(not r.ready,"ordinary load never switches old profile")
 var first=r.prepare_legacy_candidate();check(first.ok and first.snapshot.money==4777,"candidate prepared with exact3800refund+200premium")
 var store=R.Store.new(path+"/v2-candidate");var before=store.read_latest();check(before.ok,"candidate exists separately")
 check(FileAccess.get_file_as_bytes(path+"/slot0.json")==original and FileAccess.get_file_as_bytes(path+"/v1-before-v2/slot0.json")==original,"original and backup byte-identical")
 check(r.prepare_legacy_candidate().ok and store.read_latest().sequence==before.sequence,"repeat preparation does not write/credit again")
 check(not R.new(path).ready,"candidate never enables live profile")
 var injected=R.Store.new(path+"-injected/v2");check(injected.save(first.snapshot).ok,"valid candidate staged as live to test gate")
 check(not R.new(path+"-injected").ready and R.new(path+"-injected").error=="MIGRATION_CANDIDATE_ONLY","ordinary load rejects candidate even if moved")
 check(not R.new(path,true).prepare_legacy_candidate().ok,"review mode cannot prepare production candidate")
 var changed=fixture();changed.money+=10;R.LegacyStore.new(path).save(changed)
 check(not r.prepare_legacy_candidate().ok and store.read_latest().sequence==before.sequence,"changed original never replaced by stale candidate")
 var active=fixture();active.shift.mode="RUNNING";active.shift.remaining=200
 var active_path=path+"-active";R.LegacyStore.new(active_path).save(active)
 check(not R.new(active_path).prepare_legacy_candidate().ok and not FileAccess.file_exists(active_path+"/v2-candidate/slot0.json"),"active session untouched")
 var failure_path=path+"-failure";R.LegacyStore.new(failure_path).save(fixture())
 var f=FileAccess.open(failure_path+"/v2-candidate",FileAccess.WRITE);f.store_string("blocks directory creation");f.close()
 check(not R.new(failure_path).prepare_legacy_candidate().ok and not R.Store.new(failure_path+"/v2-candidate").read_latest().ok,"actual directory write failure leaves no migrated profile")
 for phase in ["prepare","restart","changed","verify"]:
  var output=[]
  var code=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/legacy_candidate_storage_test.gd","--",phase,path+"-process"],output,true)
  check(code==0 and not "ERROR:" in "\n".join(output) and "PASS:" in "\n".join(output),"separate candidate process "+phase+" "+"\n".join(output))
 if failures==0:print("PASS: byte backups, candidate idempotence/staleness/write failure, strict live gate and4 separate processes")
 quit(0 if failures==0 else 1)
func probe(phase: String,path: String):
 if phase=="prepare":R.LegacyStore.new(path).save(fixture())
 var r=R.new(path)
 if phase in ["prepare","restart"]:
  var result=r.prepare_legacy_candidate();check(result.ok and result.snapshot.money==4777,"repeat process full amount once")
  check(R.Store.new(path+"/v2-candidate").read_latest().sequence==1,"single candidate generation")
 elif phase=="changed":
  var old=fixture();old.money+=25;R.LegacyStore.new(path).save(old)
  check(not r.prepare_legacy_candidate().ok,"updated source rejected after restart")
 elif phase=="verify":
  check(not r.ready and not r.prepare_legacy_candidate().ok,"old remains live, stale candidate unusable")
  check(R.LegacyStore.new(path).read_latest().snapshot.money==802 and R.Store.new(path+"/v2-candidate").read_latest().snapshot.money==4777,"two identities remain intact")
 if failures==0:print("PASS: migration candidate process "+phase)
 quit(0 if failures==0 else 1)
