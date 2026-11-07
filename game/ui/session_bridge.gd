extends RefCounted
const V2=preload("res://persistence/repository_v2.gd")
const V1=preload("res://persistence/repository.gd")
var backend
var directory: String
var legacy=false
var training=false
var practice
var legacy_wall=0.0
var init_error=""
var ready: bool:
 get:return init_error=="" and backend!=null and backend.ready
var error: String:
 get:return init_error if init_error!="" else backend.error if backend!=null else "UNINITIALIZED"
var session:
 get:return practice if training else backend.session
func _init(path="user://saves"):
 directory=path;backend=V2.new(path)
 if not backend.ready:
  if backend.error!="LEGACY_POLICY_REQUIRED":return
  var source=V2.Candidate.read_source(path)
  if not source.ok:return
  var eligible=V2.Candidate.eligibility(source.snapshot)
  if not eligible.ok and eligible.error=="LEGACY_SESSION_IN_PROGRESS":
   legacy=true;backend=V1.new(path)
   if source.snapshot.has("shift"):
    var shift=source.snapshot.shift
    legacy_wall=Time.get_unix_time_from_datetime_string(shift.day_key+"T12:00:00")-float(shift.zone_bias)*60
  elif eligible.ok:try_migrate()
 if ready and not legacy:initialize_career()
func initialize_career():
 if not backend.session.data.has("shift"):
  if not backend.apply("enable_career"):init_error="CAREER_INIT";return
 if not backend.session.data.has("economy"):
  if not backend.apply("enable_development"):init_error="DEVELOPMENT_INIT"
func try_migrate() -> bool:
 if training:return false
 if legacy:
  var data=backend.session.data
  if data.order.state in ["BREWING","PAYMENT"]:return false
  if backend.session.shift!=null:
   var shift=backend.session.shift.data
   if shift.mode in ["RUNNING","CLOSING"] or shift.mode=="SHOP" and shift.perk!="":return false
 var source=V2.Candidate.read_source(directory)
 if not source.ok:init_error=source.error;return false
 if not V2.Candidate.eligibility(source.snapshot).ok:return false
 var target=V2.new(directory)
 var candidate=target.prepare_legacy_candidate()
 if not candidate.ok:init_error=candidate.error;return false
 if not target.activate_legacy_candidate(candidate.snapshot.migration.source_hash):init_error=target.error;return false
 backend=target;legacy=false;init_error="";return true
func preferences() -> Dictionary:return backend.session.data.get("preferences",V2.LegacyStore.Session.DEFAULT_PREFERENCES)
func set_preference(key: String,value) -> bool:return backend.set_preference(key,value)
func checkpoint() -> bool:return backend.checkpoint()
func suspend() -> bool:
 cancel_carry()
 return backend.checkpoint() if legacy else backend.suspend()
func cancel_carry():
 if not legacy:session.cup.return_cup()
func apply(method: String,args: Array=[]) -> bool:
 if not ready:return false
 if training:
  if not method in ["select_recipe","tap","take_cup","return_cup","deliver","collect","remind_wish","show_arrival_wish","finish_departure"]:return false
  return bool(practice.callv(method,args))
 return backend.apply(method,args)
func advance(seconds: float,paused=false):
 if not ready:return
 if paused:suspend();return
 if training:practice.advance(seconds);return
 if not legacy:backend.advance(seconds);return
 if not V2.Store.Schema.number(seconds):return
 var before=backend.session.snapshot();var since=backend.since_save
 backend.session.advance(seconds,false,legacy_wall)
 backend.since_save+=seconds
 var after=backend.session.snapshot()
 var transition=before.order.state!=after.order.state or before.get("shift",{}).get("mode")!=after.get("shift",{}).get("mode")
 if transition or backend.since_save>=1:
  if not backend.checkpoint():backend.session=V1.Session.restore(before);backend.since_save=since
func begin_lesson() -> bool:
 if training or not ready or legacy or not suspend():return false
 practice=V2.Service.new(884);practice.enable_career();practice.enable_development();practice.start_shift(1);training=true
 return true
func begin_training() -> bool:return begin_lesson()
func end_training() -> bool:
 if not training:return false
 training=false;practice=null;return true
