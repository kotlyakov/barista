extends RefCounted
const Service=preload("res://orders/service.gd")
const Store=preload("res://persistence/store_v2.gd")
const LegacyStore=preload("res://persistence/store.gd")
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
 var loaded=store.read_latest()
 if loaded.ok:
  if not review_mode and loaded.snapshot.get("legacy",{}).get("review_only",false):error="LEGACY_POLICY_REQUIRED";return
  session=Service.restore(loaded.snapshot);ready=session!=null
  sequence=int(loaded.sequence)
  return
 if loaded.error!="EMPTY":error=loaded.error;return
 if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory+"/v1-before-v2")) or (not review_mode and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory+"/v2-review"))):
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

func backup_v1(directory: String) -> bool:
 var destination=directory+"/v1-before-v2"
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))!=OK:error="BACKUP_DIRECTORY";return false
 for index in range(2):
  var name="/slot"+str(index)+".json"
  var path=directory+name
  if not FileAccess.file_exists(path):continue
  var source=FileAccess.open(path,FileAccess.READ)
  if source==null or source.get_length()>1048576:error="BACKUP_READ";return false
  var bytes=source.get_buffer(source.get_length());source.close()
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
