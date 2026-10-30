extends RefCounted
const Session=preload("res://orders/session.gd")
const Store=preload("res://persistence/store.gd")
var session=Session.new()
var store
var ready=false
var error=""
var since_save=0.0
var career_enabled=true
var training=false
var main_session
func _init(directory="user://saves",use_career=true) -> void:
 career_enabled=use_career
 store=Store.new(directory)
 var loaded=store.read_latest()
 if loaded.ok:
  session=Session.restore(loaded.snapshot)
  ready=true
 elif loaded.error=="EMPTY":
  if career_enabled: session.enable_shift(Time.get_unix_time_from_system(),int(Time.get_time_zone_from_system().bias))
  ready=true
  ready=checkpoint()
 else:
  error=loaded.error
func checkpoint() -> bool:
 if not ready: return false
 if training: return true
 var result=store.save(session.snapshot())
 if not result.ok:
  error=result.error
  return false
 error=""
 since_save=0
 return true
func apply(method: String,args: Array=[]) -> bool:
 if not ready or not method in ["tap","take_cup","deliver","collect","next_order","start_shift","collect_reward","purchase","choose_perk"]: return false
 var before=session.snapshot()
 var result=session.callv(method,args)
 if not result: return false
 if checkpoint(): return true
 session=Session.restore(before)
 return false
func advance(seconds: float,paused=false) -> void:
 if not ready or paused: return
 var before=session.snapshot()
 var previous_state=session.data.order.state
 session.advance(seconds)
 since_save+=maxf(0,seconds)
 if session.data.order.state!=previous_state or since_save>=1:
  if not checkpoint():
   session=Session.restore(before)
func restart() -> bool:
 if training:
  session=Session.new()
  return true
 var before=session
 var was_ready=ready
 session=Session.new()
 if career_enabled: session.enable_shift(Time.get_unix_time_from_system(),int(Time.get_time_zone_from_system().bias))
 ready=true
 if checkpoint(): return true
 session=before
 ready=was_ready
 return false

func begin_training() -> bool:
 if training or not ready: return false
 if session.shift!=null and session.shift.data.mode!="FINISHED": return false
 if not checkpoint(): return false
 main_session=session
 session=Session.new()
 training=true
 return true
func end_training() -> bool:
 if not training: return false
 session=main_session
 main_session=null
 training=false
 return true

func preferences() -> Dictionary:
 return (main_session if training else session).data.preferences
func set_preference(key: String,value) -> bool:
 if not ready: return false
 var target=main_session if training else session
 var before=target.data.preferences.duplicate()
 if not target.set_preference(key,value): return false
 var result=store.save(target.snapshot())
 if result.ok:
  error=""
  return true
 target.data.preferences=before
 error=result.error
 return false
func begin_lesson() -> bool:
 if training or not ready or not checkpoint(): return false
 main_session=session
 session=Session.new()
 training=true
 return true
