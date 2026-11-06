extends RefCounted
const Service=preload("res://orders/service.gd")
const Store=preload("res://persistence/store_v2.gd")
const LegacyStore=preload("res://persistence/store.gd")
const Candidate=preload("res://persistence/legacy_candidate.gd")
const Migrations=preload("res://persistence/migrations.gd")
var session=Service.new()
var store
var ready=false
var error=""
var since_save=0.0
var review_mode=false
# One synchronous Godot main-thread writer; simultaneous OS-process writers are
# not supported. The generation guard also rejects stale sequential instances.
var sequence=0
func _init(directory="user://saves",review_legacy=false) -> void:
 review_mode=review_legacy
 store=Store.new(directory+("/v2-review" if review_mode else "/v2"))
 if linked_path(store.directory):error="UNSAFE_MIGRATION_LINK";return
 var loaded=store.read_latest()
 if loaded.ok:
  if loaded.snapshot.has("migration") and (review_mode or loaded.snapshot.migration.candidate_only):error="MIGRATION_CANDIDATE_ONLY";return
  if not review_mode and loaded.snapshot.get("legacy",{}).get("review_only",false):error="LEGACY_POLICY_REQUIRED";return
  session=Service.restore(loaded.snapshot);ready=session!=null
  sequence=int(loaded.sequence)
  return
 if loaded.error!="EMPTY":error=loaded.error;return
 var prior_evidence=false
 for name in ["v1-before-v2","v2-review","v2-candidate","v2-activate"]:
  var evidence_path=ProjectSettings.globalize_path(directory+"/"+name)
  if DirAccess.dir_exists_absolute(evidence_path) or FileAccess.file_exists(evidence_path):prior_evidence=true
 if prior_evidence:
  error="MIGRATION_INCOMPLETE" if review_mode else "LEGACY_POLICY_REQUIRED";return
 var old=LegacyStore.new(directory).read_latest()
 if old.ok:
  if not review_mode:error="LEGACY_POLICY_REQUIRED";return
  var preview=Migrations.preview(old.snapshot)
  if not preview.ok:error=preview.error;return
  if not backup_v1(directory):return
  session=Service.restore(preview.snapshot)
 elif old.error!="EMPTY":error=old.error;return
 else:
  session.data.preferences=LegacyStore.Session.DEFAULT_PREFERENCES.duplicate()
  session.data.upgrades={"grind":0,"brew":0,"milk":0,"tuning":0,"grace":0,"ads":0}
 ready=true
 if not checkpoint():ready=false

func prepare_legacy_candidate() -> Dictionary:
 if review_mode:return {"ok":false,"error":"REVIEW_MODE"}
 var root_directory=store.directory.get_base_dir()
 if migration_links(root_directory):return {"ok":false,"error":"UNSAFE_MIGRATION_LINK"}
 var live=Store.new(root_directory+"/v2").read_latest()
 if live.ok:return {"ok":false,"error":"V2_ALREADY_EXISTS"}
 if live.error!="EMPTY":return live
 var source=Candidate.read_source(root_directory)
 if not source.ok:return source
 var allowed=Candidate.eligibility(source.snapshot)
 if not allowed.ok:return allowed
 var converted=Candidate.convert(source.snapshot,int(source.sequence))
 if not converted.ok:return converted
 var canonical=JSON.parse_string(JSON.stringify(converted.snapshot,"",true,true))
 var candidate_store=Store.new(root_directory+"/v2-candidate")
 var existing=candidate_store.read_latest()
 if existing.ok:
  var receipt=existing.snapshot.get("migration",{})
  if not Candidate.valid_receipt(receipt):return {"ok":false,"error":"INVALID_CANDIDATE_RECEIPT"}
  if receipt.source_hash!=JSON.stringify(source.snapshot).sha256_text() or receipt.source_sequence!=source.sequence:return {"ok":false,"error":"STALE_LEGACY_SOURCE"}
  if existing.snapshot!=canonical:return {"ok":false,"error":"CANDIDATE_MODIFIED"}
  if not backup_v1(root_directory):return {"ok":false,"error":error}
  return {"ok":true,"snapshot":existing.snapshot,"sequence":existing.sequence,"reused":true}
 if existing.error!="EMPTY":return existing
 if not backup_v1(root_directory):return {"ok":false,"error":error}
 var fresh=Candidate.read_source(root_directory)
 if not fresh.ok or fresh.sequence!=source.sequence or JSON.stringify(fresh.snapshot).sha256_text()!=converted.snapshot.migration.source_hash:return {"ok":false,"error":"STALE_LEGACY_SOURCE"}
 var saved=candidate_store.save(converted.snapshot,0)
 if not saved.ok:return saved
 return {"ok":true,"snapshot":converted.snapshot,"sequence":saved.sequence,"reused":false}

func activate_legacy_candidate(expected_source_hash: String) -> bool:
 if review_mode:error="REVIEW_MODE";return false
 if expected_source_hash.length()!=64 or not expected_source_hash.is_valid_hex_number(false):error="INVALID_SOURCE_HASH";return false
 var root_directory=store.directory.get_base_dir()
 if migration_links(root_directory):error="UNSAFE_MIGRATION_LINK";return false
 var live=store.read_latest()
 if live.ok:
  var receipt=live.snapshot.get("migration",{})
  if receipt.is_empty() or receipt.get("candidate_only",true):error="V2_ALREADY_EXISTS";return false
  if receipt.source_hash!=expected_source_hash:error="STALE_LEGACY_SOURCE";return false
  # A retry on the current writer is an identity operation, including its
  # fractional clock and drag gesture. Stale objects still reload current disk.
  if ready and sequence==int(live.sequence) and session.data.get("migration",{}).get("source_hash")==expected_source_hash:
   error="";return true
  return reload()
 if live.error!="EMPTY":error=live.error;return false
 var displayed_source=Candidate.read_source(root_directory)
 if not displayed_source.ok:error=displayed_source.error;return false
 if JSON.stringify(displayed_source.snapshot).sha256_text()!=expected_source_hash:error="STALE_LEGACY_SOURCE";return false
 var prepared=prepare_legacy_candidate()
 if not prepared.ok:error=prepared.error;return false
 if prepared.snapshot.migration.source_hash!=expected_source_hash:error="STALE_LEGACY_SOURCE";return false
 var snapshot_data=prepared.snapshot.duplicate(true)
 snapshot_data.migration.candidate_only=false
 var canonical=JSON.parse_string(JSON.stringify(snapshot_data,"",true,true))
 var stage_directory=root_directory+"/v2-activate"
 var staged_store=Store.new(stage_directory)
 var absolute_stage=ProjectSettings.globalize_path(stage_directory)
 if FileAccess.file_exists(absolute_stage) and not DirAccess.dir_exists_absolute(absolute_stage):error="ACTIVATION_STAGE_DIRECTORY";return false
 var files=DirAccess.get_files_at(stage_directory) if DirAccess.dir_exists_absolute(absolute_stage) else PackedStringArray()
 if DirAccess.dir_exists_absolute(absolute_stage) and not DirAccess.get_directories_at(stage_directory).is_empty():error="ACTIVATION_STAGE_UNKNOWN";return false
 for name in files:
  if not name in ["slot0.json","slot1.json","slot0.json.tmp","slot1.json.tmp"]:error="ACTIVATION_STAGE_UNKNOWN";return false
 var first=staged_store.read_slot(0);var second=staged_store.read_slot(1)
 for slot in [first,second]:
  if not slot.state in ["MISSING","VALID"]:error="ACTIVATION_STAGE_CORRUPT";return false
 if first.state=="VALID" and (first.sequence!=1 or first.snapshot!=canonical):error="ACTIVATION_STAGE_MODIFIED";return false
 if second.state=="VALID" and (first.state!="VALID" or second.sequence!=2 or second.snapshot!=canonical):error="ACTIVATION_STAGE_MODIFIED";return false
 if "slot0.json.tmp" in files and (first.state!="MISSING" or "slot1.json.tmp" in files):error="ACTIVATION_STAGE_UNKNOWN";return false
 if "slot1.json.tmp" in files and (first.state!="VALID" or second.state!="MISSING"):error="ACTIVATION_STAGE_UNKNOWN";return false
 # Unlink recognized interrupted files before opening for WRITE. This also
 # prevents an existing hard link from truncating the original v1 inode.
 for name in ["slot0.json.tmp","slot1.json.tmp"]:
  if name in files and DirAccess.remove_absolute(ProjectSettings.globalize_path(stage_directory+"/"+name))!=OK:error="ACTIVATION_STAGE_CLEANUP";return false
 if first.state=="MISSING" and DirAccess.dir_exists_absolute(absolute_stage):
  if DirAccess.remove_absolute(absolute_stage)!=OK:error="ACTIVATION_STAGE_CLEANUP";return false
 var staged=staged_store.read_latest()
 if not staged.ok and staged.error!="EMPTY":error=staged.error;return false
 for attempt in range(2):
  var a=staged_store.read_slot(0);var b=staged_store.read_slot(1)
  if a.state=="VALID" and b.state=="VALID":break
  var saved=staged_store.save(snapshot_data,int(staged.sequence) if staged.ok else 0)
  if not saved.ok:error=saved.error;return false
  staged=staged_store.read_latest()
  if not staged.ok:error=staged.error;return false
 if staged_store.read_slot(0).state!="VALID" or staged_store.read_slot(1).state!="VALID":error="ACTIVATION_STAGE_INCOMPLETE";return false
 var fresh=Candidate.read_source(root_directory)
 if not fresh.ok or fresh.sequence!=snapshot_data.migration.source_sequence or JSON.stringify(fresh.snapshot).sha256_text()!=expected_source_hash:error="STALE_LEGACY_SOURCE";return false
 if not backup_v1(root_directory):return false
 var destination=ProjectSettings.globalize_path(store.directory)
 if linked_path(destination) or DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):error="V2_ALREADY_EXISTS";return false
 # Same filesystem, one synchronous writer: publish both slots together.
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(stage_directory),destination)!=OK:error="ACTIVATION_RENAME";return false
 return reload()

static func linked_path(path: String) -> bool:
 var absolute=ProjectSettings.globalize_path(path)
 var parent=DirAccess.open(absolute.get_base_dir())
 return parent!=null and parent.is_link(absolute)

static func migration_links(directory: String) -> bool:
 for name in ["slot0.json","slot1.json","v2","v2-review","v2-candidate","v2-activate","v1-before-v2"]:
  var path=directory+"/"+name
  if linked_path(path):return true
  if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):continue
  var access=DirAccess.open(path)
  if access==null:return true
  access.include_hidden=true;access.include_navigational=false
  if access.list_dir_begin()!=OK:return true
  var entry=access.get_next()
  while entry!="":
   if access.is_link(entry):access.list_dir_end();return true
   entry=access.get_next()
  access.list_dir_end()
 return false

func backup_v1(directory: String) -> bool:
 if migration_links(directory):error="UNSAFE_MIGRATION_LINK";return false
 var destination=directory+"/v1-before-v2"
 for index in range(2):
  var name="/slot"+str(index)+".json"
  if not FileAccess.file_exists(directory+name) and FileAccess.file_exists(destination+name):error="BACKUP_PRESENCE_MISMATCH";return false
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))!=OK:error="BACKUP_DIRECTORY";return false
 for index in range(2):
  var name="/slot"+str(index)+".json"
  var path=directory+name
  if not FileAccess.file_exists(path):continue
  var source=FileAccess.open(path,FileAccess.READ)
  if source==null or source.get_length()>1048576:error="BACKUP_READ";return false
  var expected=int(source.get_length())
  var bytes=source.get_buffer(expected)
  var read_status=source.get_error();var final_length=int(source.get_length());source.close()
  if bytes.size()!=expected or read_status!=OK or final_length!=expected:error="BACKUP_READ";return false
  var target=destination+name
  if not FileAccess.file_exists(target):
   var f=FileAccess.open(target,FileAccess.WRITE)
   if f==null:error="BACKUP_WRITE";return false
   f.store_buffer(bytes);f.flush()
   var status=f.get_error();f.close()
   if status!=OK:error="BACKUP_FLUSH";return false
  if FileAccess.get_file_as_bytes(target)!=bytes:error="BACKUP_MISMATCH";return false
 return true

func checkpoint() -> bool:
 if not ready:return false
 var result=store.save(session.snapshot(),sequence)
 if not result.ok:error=result.error;return false
 sequence=int(result.sequence)
 error="";since_save=0
 return true

func apply(method: String,args: Array=[]) -> bool:
 var arities={"spawn_visit":[0,2],"select_recipe":[1,1],"tap":[1,1],"take_cup":[0,0],"return_cup":[0,0],"deliver":[2,2],"collect":[1,1],"remind_wish":[1,1],"finish_departure":[1,1],"claim_legacy_reward":[0,0],"enable_career":[0,0],"start_shift":[1,1],"finish_summary":[1,1],"enable_development":[0,0],"buy_perk":[2,2],"skip_perk":[1,1],"buy_equipment":[2,2],"buy_module":[1,1],"equip_module":[2,2],"remove_module":[1,1],"reserve_gift":[1,1],"claim_goal":[2,2],"promote_league":[1,1]}
 if not ready or not arities.has(method) or args.size()<arities[method][0] or args.size()>arities[method][1]:return false
 if review_mode and method=="enable_development":return false
 var string_args={"spawn_visit":2,"select_recipe":1,"buy_perk":1,"buy_equipment":1,"buy_module":1,"equip_module":1,"reserve_gift":1,"claim_goal":1}
 for i in range(args.size()):
  if i<int(string_args.get(method,0)):
   if not args[i] is String:return false
  elif not Store.Schema.integer(args[i],-1):return false
 var before=session.snapshot();var carrying=session.cup.carrying
 var result=session.callv(method,args)
 if not result:return false
 if checkpoint():return true
 rollback(before,carrying)
 return false

func rollback(before: Dictionary,carrying: bool) -> void:
 session=Service.restore(before)
 if session==null:ready=false;error="ROLLBACK_INVALID";return
 session.cup.carrying=carrying

func reload() -> bool:
 var loaded=store.read_latest()
 if not loaded.ok:error=loaded.error;ready=false;return false
 if loaded.snapshot.has("migration") and (review_mode or loaded.snapshot.migration.candidate_only):error="MIGRATION_CANDIDATE_ONLY";ready=false;return false
 if not review_mode and loaded.snapshot.get("legacy",{}).get("review_only",false):error="LEGACY_POLICY_REQUIRED";ready=false;return false
 session=Service.restore(loaded.snapshot);sequence=int(loaded.sequence);since_save=0;error="";ready=session!=null
 return ready

func suspend() -> bool:
 if not ready:return false
 session.return_cup()
 return checkpoint() if since_save>0 else true

static func transition_signature(snapshot_data: Dictionary) -> Array:
 var result=[]
 if snapshot_data.has("shift"):
  var s=snapshot_data.shift
  result.append([s.day_number,s.phase,s.summary_id,s.last_summary_id])
 for v in snapshot_data.visits:result.append([v.id,v.state,v.reaction_applied])
 for p in snapshot_data.payments:result.append([p.id,p.state])
 return result

func advance(seconds: float,paused=false) -> void:
 if not ready:return
 if paused:suspend();return
 if not Store.Schema.number(seconds) or not Store.Schema.number(session.data.clock+seconds):return
 var before=session.snapshot();var previous=since_save;var carrying=session.cup.carrying
 session.advance(seconds)
 since_save+=session.data.clock-float(before.clock)
 if since_save>=1 or transition_signature(before)!=transition_signature(session.snapshot()):
  if not checkpoint():rollback(before,carrying);since_save=previous

func set_preference(key: String,value) -> bool:
 if not ready or not LegacyStore.Session.valid_preference(key,value):return false
 var before=session.snapshot();var carrying=session.cup.carrying
 if not session.data.has("preferences"):session.data.preferences=LegacyStore.Session.DEFAULT_PREFERENCES.duplicate()
 session.data.preferences[key]=value if value is bool else float(value)
 if checkpoint():return true
 rollback(before,carrying)
 return false
