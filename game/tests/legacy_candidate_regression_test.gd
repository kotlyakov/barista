extends SceneTree
const R=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func fixture():return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/shop.json"))
func _init():
 var root_path="user://candidate-regression-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 for kind in ["future","truncated","parity","bad_hash"]:
  var path=root_path+kind;R.LegacyStore.new(path).save(fixture())
  var envelope=JSON.parse_string(FileAccess.get_file_as_string(path+"/slot0.json"));envelope.sequence=2
  if kind=="future":envelope.schema_version=99
  if kind=="parity":envelope.sequence=1
  if kind=="bad_hash":envelope.sha256="0000"
  var f=FileAccess.open(path+"/slot1.json",FileAccess.WRITE);f.store_string("{broken" if kind=="truncated" else JSON.stringify(envelope));f.close()
  var result=R.new(path).prepare_legacy_candidate()
  check(not result.ok,"strict source rejects "+kind+" instead of importing older funds")
  check(not FileAccess.file_exists(path+"/v2-candidate/slot0.json"),"unsafe source never creates candidate")
 for change in ["money","trust"]:
  var path=root_path+change;R.LegacyStore.new(path).save(fixture());var r=R.new(path)
  check(r.prepare_legacy_candidate().ok,"initial canonical candidate")
  var store=R.Store.new(path+"/v2-candidate");var loaded=store.read_latest();var altered=loaded.snapshot
  if change=="money":altered.money+=500
  else:altered.profiles["guest-01"].trust_l=0.9
  check(store.save(altered,loaded.sequence).ok,"externally altered candidate otherwise valid")
  check(not r.prepare_legacy_candidate().ok,"reused candidate must equal complete canonical conversion: "+change)
 var path=root_path+"-backup-presence";var old=fixture();R.LegacyStore.new(path).save(old)
 old.money+=100;R.LegacyStore.new(path).save(old)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path+"/v1-before-v2"))
 var bytes=FileAccess.get_file_as_bytes(path+"/slot1.json");var f=FileAccess.open(path+"/v1-before-v2/slot1.json",FileAccess.WRITE);f.store_buffer(bytes);f.close()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path+"/slot1.json"))
 check(not R.new(path).prepare_legacy_candidate().ok,"extra backup source slot cannot be silently skipped")
 check(FileAccess.get_file_as_bytes(path+"/v1-before-v2/slot1.json")==bytes,"mismatching backup evidence remains intact")
 old=fixture();old.shift.perk=old.shift.offers[0]
 var selected=load("res://persistence/legacy_candidate.gd").convert(old,1)
 check(not selected.ok and selected.error=="LEGACY_SESSION_IN_PROGRESS","selected legacy perk is honoured for one old shift")
 path=root_path+"-candidate-only"
 var result=load("res://persistence/legacy_candidate.gd").convert(fixture(),1)
 R.Store.new(path+"/v2-candidate").save(result.snapshot)
 check(not R.new(path).ready and not R.new(path,true).ready,"candidate-only evidence blocks fresh zero-wallet initialization")
 check(not FileAccess.file_exists(path+"/v2/slot0.json") and not FileAccess.file_exists(path+"/v2-review/slot0.json"),"candidate evidence never produces replacement empty profile")
 if failures==0:print("PASS: strict all-slot source inspection and sealed complete candidate reuse")
 quit(0 if failures==0 else 1)
