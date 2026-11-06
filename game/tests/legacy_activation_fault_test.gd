extends SceneTree
const R=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func fixture():return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/summary.json"))
func _init():
 if not R.new("user://activation-fault-missing-"+str(Time.get_ticks_usec())).has_method("activate_legacy_candidate"):print("FAIL: recoverable live publication absent");quit(1);return
 var root_path="user://activation-fault-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 for phase in ["empty","temp","one_slot","published_stage","unknown","corrupt","write_failure","bad_backup","changed_source","existing_live"]:
  var path=root_path+phase;R.LegacyStore.new(path).save(fixture());var r=R.new(path);var c=r.prepare_legacy_candidate();var hash=c.snapshot.migration.source_hash
  var snapshot_data=c.snapshot.duplicate(true);snapshot_data.migration.candidate_only=false
  var stage=path+"/v2-activate"
  if phase in ["empty","temp","unknown","corrupt"]:
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage))
   if phase!="empty":
    var name={"temp":"slot0.json.tmp","unknown":"something-valuable","corrupt":"slot0.json"}[phase]
    var f=FileAccess.open(stage+"/"+name,FileAccess.WRITE);f.store_string("{partial");f.close()
  if phase in ["one_slot","published_stage"]:
   var store=R.Store.new(stage);store.save(snapshot_data,0)
   if phase=="published_stage":store.save(snapshot_data,1)
  if phase=="write_failure":
   var f=FileAccess.open(stage,FileAccess.WRITE);f.store_string("blocks directory creation");f.close()
  if phase=="bad_backup":
   var f=FileAccess.open(path+"/v1-before-v2/slot0.json",FileAccess.WRITE);f.store_string("broken");f.close()
  if phase=="changed_source":
   var changed=fixture();changed.money+=10;R.LegacyStore.new(path).save(changed)
  if phase=="existing_live":
   var live=R.Service.new();live.data.money=999;R.Store.new(path+"/v2").save(live.snapshot(),0)
  var good=phase in ["empty","temp","one_slot","published_stage"]
  check(r.activate_legacy_candidate(hash)==good,"publication fault boundary "+phase)
  if good:check(R.new(path).ready and R.new(path).session.data.money==4777,"resumed canonical complete live "+phase)
  elif phase=="existing_live":check(R.new(path).session.data.money==999,"unrelated live preserved")
  else:check(not FileAccess.file_exists(path+"/v2/slot0.json"),"failed activation never publishes "+phase)
  check(R.LegacyStore.new(path).read_latest().snapshot.money==787 if phase=="changed_source" else R.LegacyStore.new(path).read_latest().snapshot.money==777,"old money unchanged except explicit fixture update")
  if phase=="unknown":check(FileAccess.file_exists(stage+"/something-valuable"),"unknown staging file not removed")
 for kind in ["bad_sibling","unknown_with_slot","subdir_with_slot","high_generation","slot1_only"]:
  var path=root_path+"-sealed-"+kind;R.LegacyStore.new(path).save(fixture());var r=R.new(path);var c=r.prepare_legacy_candidate()
  var hash=c.snapshot.migration.source_hash;var snap=c.snapshot.duplicate(true);snap.migration.candidate_only=false
  var directory=path+"/v2-activate";var store=R.Store.new(directory);store.save(snap,0)
  if kind=="bad_sibling":
   var f=FileAccess.open(directory+"/slot1.json",FileAccess.WRITE);f.store_string("{valuable corrupted evidence");f.close()
  elif kind=="unknown_with_slot":
   var f=FileAccess.open(directory+"/keep-me.txt",FileAccess.WRITE);f.store_string("valuable");f.close()
  elif kind=="subdir_with_slot":DirAccess.make_dir_absolute(ProjectSettings.globalize_path(directory+"/keep-me"))
  elif kind=="high_generation":
   var payload=JSON.stringify(snap,"",true,true)
   for index in range(2):
    var generation=2147483647-index
    var f=FileAccess.open(directory+"/slot"+str(index)+".json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"schema_version":2,"sequence":generation,"payload":payload,"sha256":R.Store.digest(generation,payload)}));f.close()
  elif kind=="slot1_only":
   store.save(snap,1);DirAccess.remove_absolute(ProjectSettings.globalize_path(directory+"/slot0.json"))
  check(not r.activate_legacy_candidate(hash),"strict stage rejects masked corruption/unknown layout/generation: "+kind)
  check(not FileAccess.file_exists(path+"/v2/slot0.json") and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)),"rejected stage evidence preserved: "+kind)
 var link_api=DirAccess.open(ProjectSettings.globalize_path("user://"))
 for kind in ["temp_symlink","stage_symlink","destination_symlink","temp_hardlink"]:
  var path=root_path+"-link-"+kind;R.LegacyStore.new(path).save(fixture());var r=R.new(path);var c=r.prepare_legacy_candidate();var snap=c.snapshot.duplicate(true);snap.migration.candidate_only=false
  var directory=path+"/v2-activate";var actual=path+"-external"
  var original=FileAccess.get_file_as_bytes(path+"/slot0.json")
  if kind=="stage_symlink":
   R.Store.new(actual).save(snap,0)
   check(link_api.create_link(ProjectSettings.globalize_path(actual),ProjectSettings.globalize_path(directory))==OK,"create staging link fixture")
  elif kind=="destination_symlink":check(link_api.create_link(ProjectSettings.globalize_path(actual),ProjectSettings.globalize_path(path+"/v2"))==OK,"create dangling destination fixture")
  else:
   R.Store.new(directory).save(snap,0)
   if kind=="temp_symlink":check(link_api.create_link(ProjectSettings.globalize_path(path+"/slot0.json"),ProjectSettings.globalize_path(directory+"/slot1.json.tmp"))==OK,"create temp symlink fixture")
   else:
    var output=[];check(OS.execute("ln",[ProjectSettings.globalize_path(path+"/slot0.json"),ProjectSettings.globalize_path(directory+"/slot1.json.tmp")],output,true)==0,"create temp hardlink fixture")
  var result=r.activate_legacy_candidate(c.snapshot.migration.source_hash)
  check(FileAccess.get_file_as_bytes(path+"/slot0.json")==original,"links never truncate original source: "+kind)
  check(result if kind=="temp_hardlink" else not result,"reject symlink or safely unlink known interrupted hardlink: "+kind)
 var orphan=root_path+"orphan";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(orphan+"/v2-activate"))
 check(not R.new(orphan).ready,"staging evidence alone prevents fresh zero profile")
 if failures==0:print("PASS: interrupted publication recovery, unknown/corrupt stage preservation, actual directory failure, stale sources/backups and existing live")
 quit(0 if failures==0 else 1)
