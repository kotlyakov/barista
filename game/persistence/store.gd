extends RefCounted
const Session=preload("res://orders/session.gd")
var directory: String
func _init(path="user://saves") -> void:
 directory=path
static func number(value,minimum=0.0,maximum=1.0e12) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum
static func integer(value,minimum=0,maximum=2147483647) -> bool:
 return number(value,minimum,maximum) and float(value)==floor(float(value))
static func valid(s) -> bool:
 if not s is Dictionary: return false
 if not number(s.get("clock")) or not integer(s.get("money")) or not integer(s.get("next_id"),2) or not integer(s.get("streak")): return false
 if s.has("preferences"):
  if not s.preferences is Dictionary: return false
  for key in s.preferences:
   if not Session.DEFAULT_PREFERENCES.has(key): return false
  for key in Session.DEFAULT_PREFERENCES:
   if key=="muted" and not s.preferences.has(key): continue
   if not Session.valid_preference(key,s.preferences.get(key)): return false
 var upgrades=s.get("upgrades")
 if not upgrades is Dictionary or upgrades.size()!=Session.UPGRADES.size(): return false
 for id in Session.UPGRADES:
  if not integer(upgrades.get(id),0,Session.UPGRADES[id]): return false
 var profiles=s.get("profiles")
 if not profiles is Dictionary or profiles.size()!=6: return false
 for n in range(6):
  var id="guest-%02d" % (n+1)
  var p=profiles.get(id)
  if not p is Dictionary or not p.get("mood") in ["neutral","happy","annoyed"] or not p.get("last_reaction") is String: return false
  if p.last_reaction.length()>300 or not integer(p.get("relationship"),-100,100) or not integer(p.get("visits")): return false
 if not s.get("rng_state") is String or not s.rng_state.is_valid_int(): return false
 for p in profiles.values():
  if not p.get("history") is Array or p.history.size()>20 or not Session.PRICES.has(p.get("favorite")): return false
  for entry in p.history:
   if not entry is Dictionary or not number(entry.get("quality"),-1,1) or not entry.get("late") is bool: return false
 var o=s.get("order")
 var b=s.get("brew")
 if not o is Dictionary or not b is Dictionary: return false
 if not integer(o.get("id"),1) or o.id>=s.next_id or not profiles.has(o.get("customer_id")) or not Session.PRICES.has(o.get("recipe")): return false
 if not o.get("state") in ["BREWING","PAYMENT","COLLECTED","LEFT","UNPAID","DORMANT","CLOSED"] or not number(o.get("first_tap"),-1,s.clock) or not number(o.get("patience"),0,70): return false
 if not o.get("late") is bool or not o.get("reaction_applied") is bool: return false
 if b.get("recipe")!=o.recipe or not b.get("taps") is Array or not b.get("targets") is Array: return false
 var required=Session.Brew.TARGETS[o.recipe].size()
 if b.taps.size()!=required or b.targets.size()!=required or not integer(b.get("stage"),0,required-1) or not integer(b.get("grace"),0,4) or not number(b.get("damage_scale"),0,1) or not b.get("locked") is bool: return false
 for i in range(required):
  if not integer(b.targets[i],1,100) or not integer(b.taps[i]): return false
  if i<int(b.stage) and b.taps[i]<b.targets[i]: return false
  if i>int(b.stage) and b.taps[i]!=0: return false
 if b.locked:
  for i in range(required):
   if b.taps[i]<b.targets[i]: return false
 if o.has("arrival_remaining") and not number(o.arrival_remaining,0,6): return false
 var pay=o.get("payment")
 if not pay is Dictionary: return false
 if o.state in ["PAYMENT","COLLECTED","UNPAID"]:
  if not b.locked or not o.reaction_applied: return false
  if not integer(pay.get("id"),1) or pay.id!=o.id or not integer(pay.get("amount"),0,1000) or not number(pay.get("deadline")) or not pay.get("collected") is bool: return false
  if pay.collected!=(o.state=="COLLECTED"): return false
 elif not pay.is_empty(): return false
 if s.has("shift"):
  if not Session.Shift.valid(s.shift) or not s.get("stats") is Dictionary or not integer(s.stats.get("delivered")) or not integer(s.stats.get("good")) or s.stats.good>s.stats.delivered: return false
 return true
func _read_slot(index: int):
 var path=directory+"/slot"+str(index)+".json"
 if not FileAccess.file_exists(path): return null
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null: return null
 if file.get_length()>1048576: return null
 var parser=JSON.new()
 if parser.parse(file.get_as_text())!=OK: return null
 var envelope=parser.data
 if not envelope is Dictionary or envelope.get("schema_version")!=1 or not integer(envelope.get("sequence"),1) or not envelope.get("payload") is String: return null
 if envelope.get("sha256")!=envelope.payload.sha256_text(): return null
 if parser.parse(envelope.payload)!=OK: return null
 var snapshot_data=parser.data
 if not valid(snapshot_data): return null
 return {"sequence":int(envelope.sequence),"snapshot":snapshot_data}
func read_latest() -> Dictionary:
 var a=_read_slot(0)
 var b=_read_slot(1)
 var exists=FileAccess.file_exists(directory+"/slot0.json") or FileAccess.file_exists(directory+"/slot1.json")
 if a==null and b==null: return {"ok":false,"error":"CORRUPT" if exists else "EMPTY"}
 var chosen=a if b==null or (a!=null and a.sequence>=b.sequence) else b
 return {"ok":true,"sequence":chosen.sequence,"snapshot":chosen.snapshot,"recovered":exists and (a==null or b==null)}
func save(snapshot_data: Dictionary) -> Dictionary:
 if not valid(snapshot_data): return {"ok":false,"error":"INVALID_STATE"}
 var status=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 if status!=OK: return {"ok":false,"error":"DIRECTORY"}
 var previous=read_latest()
 var sequence=int(previous.get("sequence",0))+1
 var target=directory+"/slot"+str((sequence-1)%2)+".json"
 var payload=JSON.stringify(snapshot_data)
 var temp=target+".tmp"
 var file=FileAccess.open(temp,FileAccess.WRITE)
 if file==null: return {"ok":false,"error":"WRITE"}
 file.store_string(JSON.stringify({"schema_version":1,"sequence":sequence,"payload":payload,"sha256":payload.sha256_text()}))
 file.flush()
 var write_error=file.get_error()
 file.close()
 if write_error!=OK: return {"ok":false,"error":"FLUSH"}
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(target))!=OK: return {"ok":false,"error":"RENAME"}
 return {"ok":true}
