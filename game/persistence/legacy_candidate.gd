extends RefCounted
# D16 accepted by owner. Preparation still produces a separate candidate.
const LegacyStore=preload("res://persistence/store.gd")
const POLICY="safe-boundary-refund-v1"
const PRICES=[400,800,1400]
static func eligibility(old) -> Dictionary:
 if not LegacyStore.valid(old):return {"ok":false,"error":"INVALID_LEGACY"}
 for n in range(6):
  if not old.profiles.has("guest-%02d"%(n+1)):return {"ok":false,"error":"INVALID_LEGACY_PROFILE_IDS"}
 # Never reinterpret a coffee, payment or an already started legacy perk.
 if old.order.state in ["BREWING","PAYMENT"] or (old.get("shift",{}).get("mode","") in ["RUNNING","CLOSING"] or old.get("shift",{}).get("perk","")!="" and old.get("shift",{}).get("mode","")=="SHOP"):
  return {"ok":false,"error":"LEGACY_SESSION_IN_PROGRESS"}
 return {"ok":true}
static func read_source(directory: String) -> Dictionary:
 # Preparation must not downgrade to an older slot after corruption/future data.
 # The old live Session keeps its original recovery policy; this gate is stricter.
 var valid=[]
 for index in range(2):
  var path=directory+"/slot"+str(index)+".json"
  if not FileAccess.file_exists(path):continue
  var f=FileAccess.open(path,FileAccess.READ)
  if f==null or f.get_length()>1048576:return {"ok":false,"error":"LEGACY_SLOT_READ"}
  var parser=JSON.new()
  if parser.parse(f.get_as_text())!=OK or not parser.data is Dictionary:return {"ok":false,"error":"LEGACY_SLOT_CORRUPT"}
  var e=parser.data
  if e.get("schema_version")!=1:return {"ok":false,"error":"UNSUPPORTED_LEGACY_VERSION"}
  if not LegacyStore.integer(e.get("sequence"),1) or (int(e.sequence)-1)%2!=index or not e.get("payload") is String:return {"ok":false,"error":"LEGACY_SLOT_GENERATION"}
  if e.get("sha256")!=e.payload.sha256_text() or parser.parse(e.payload)!=OK or not LegacyStore.valid(parser.data):return {"ok":false,"error":"LEGACY_SLOT_CORRUPT"}
  valid.append({"ok":true,"sequence":int(e.sequence),"snapshot":parser.data})
 if valid.is_empty():return {"ok":false,"error":"EMPTY"}
 var latest=valid[0]
 for item in valid:
  if item.sequence>latest.sequence:latest=item
 return latest

static func refund(old: Dictionary) -> int:
 var amount=0
 for key in ["tuning","grace"]:
  for level in range(int(old.upgrades[key])):amount+=PRICES[level]
 return amount
static func reward(old: Dictionary) -> int:
 var shift=old.get("shift",{})
 return 200 if shift.get("mode")=="SUMMARY" and shift.get("success",false) and not shift.get("reward_collected",false) else 0
static func valid_receipt(m) -> bool:
 if not m is Dictionary or m.size()!=7 or m.get("policy")!=POLICY or not m.get("candidate_only") is bool or not LegacyStore.integer(m.get("source_sequence"),1):return false
 var old=m.get("source_snapshot")
 if not eligibility(old).ok:return false
 if not m.get("source_hash") is String or m.source_hash!=JSON.stringify(old).sha256_text():return false
 if not LegacyStore.integer(m.get("refund"),0,3800) or not LegacyStore.integer(m.get("reward"),0,200):return false
 return m.refund==refund(old) and m.reward==reward(old)
static func convert(old,source_sequence=1) -> Dictionary:
 var allowed=eligibility(old)
 if not allowed.ok:return allowed
 if not LegacyStore.integer(source_sequence,1):return {"ok":false,"error":"INVALID_SOURCE_GENERATION"}
 var compensation=refund(old);var premium=reward(old)
 if not LegacyStore.integer(float(old.money)+compensation+premium):return {"ok":false,"error":"WALLET_OVERFLOW"}
 var s=load("res://orders/service.gd").new()
 s.data.money=int(old.money)+compensation+premium;s.data.clock=float(old.clock);s.data.streak=int(old.streak)
 s.data.rng_state=old.rng_state;s.data.cup_id=int(old.next_id);s.data.next_id=int(old.next_id)+1
 s.data.upgrades=old.upgrades.duplicate(true);s.data.upgrades.tuning=0;s.data.upgrades.grace=0
 s.data.preferences=LegacyStore.Session.DEFAULT_PREFERENCES.duplicate()
 for key in old.get("preferences",{}):s.data.preferences[key]=old.preferences[key]
 for key in old.profiles:
  var profile=old.profiles[key].duplicate(true)
  profile.legacy_history=profile.history.duplicate(true);profile.history=[];profile.trust_l=0.5
  s.data.profiles[key]=profile
 s.data.migration={"policy":POLICY,"candidate_only":true,"source_snapshot":old.duplicate(true),"source_hash":JSON.stringify(old).sha256_text(),"source_sequence":int(source_sequence),"refund":compensation,"reward":premium}
 if not s.enable_career() or not s.enable_development():return {"ok":false,"error":"CANDIDATE_INITIALIZATION"}
 var snapshot_data=s.snapshot()
 if not s.Schema.valid(snapshot_data):return {"ok":false,"error":"CANDIDATE_INVALID"}
 return {"ok":true,"snapshot":snapshot_data,"warnings":["CANDIDATE_ONLY_REQUIRES_ACTIVATION","LEGACY_FINISHED_BEFORE_NEW_CAREER","FULL_REFUND_D16_ACCEPTED"]}
