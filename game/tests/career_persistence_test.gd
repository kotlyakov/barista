extends SceneTree
const Repo=preload("res://persistence/repository_v2.gd")
class FailureStore:
 extends RefCounted
 func save(_snapshot,_sequence=-1) -> Dictionary:return {"ok":false,"error":"FORCED_WRITE"}
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok:failures+=1;push_error(text)
func _init() -> void:
 if not Repo.Service.new().has_method("enable_career"):
  print("FAIL: persisted career transitions absent");quit(1);return
 var args=OS.get_cmdline_user_args()
 if args.size()==2:probe(args[0],args[1]);return
 var path="user://career-save-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 var r=Repo.new(path)
 check(r.apply("enable_career"),"career init committed")
 var before=r.session.snapshot();var healthy=r.store;r.store=FailureStore.new()
 check(not r.apply("start_shift",[1]) and r.session.snapshot()==before,"failed start rolls back forecast/RNG/IDs/phase")
 r.store=healthy;check(r.apply("start_shift",[1]),"start retry committed once")
 r.advance(300)
 var summary=r.session.data.shift.summary_id
 check(Repo.new(path).session.data.shift.phase=="SUMMARY","terminal transition checkpoint immediate")
 before=r.session.snapshot();r.store=FailureStore.new()
 check(not r.apply("finish_summary",[summary]) and r.session.snapshot()==before,"failed day transition preserves old summary and event RNG")
 r.store=healthy;check(r.apply("finish_summary",[summary]),"next preparation committed")
 var restored=Repo.new(path)
 check(restored.session.data.shift.day_number==2 and not restored.apply("finish_summary",[summary]),"restart does not replay day increment")
 var malformed=restored.session.snapshot();malformed.shift.phase="RUNNING"
 check(Repo.Store.Schema.valid(restored.session.snapshot()) and not Repo.Store.Schema.valid(malformed),"external phase/timestamp validation")
 for phase in ["write","resume","collect","verify"]:
  var output=[]
  var result=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/career_persistence_test.gd","--",phase,path+"-process"],output,true)
  var text="\n".join(output)
  check(result==0 and not "ERROR:" in text and "PASS:" in text,"separate career process "+phase+": "+text)
 if failures==0:print("PASS: atomic start/next-day rollback, strict shift snapshots, summary idempotence and four separate closing/restart processes")
 quit(0 if failures==0 else 1)
func probe(phase: String,path: String) -> void:
 var r=Repo.new(path)
 check(r.ready,"probe repository ready")
 if not r.ready:quit(1);return
 if phase=="write":
  r.apply("enable_career");r.apply("start_shift",[1]);r.advance(299)
  for v in r.session.data.visits.duplicate():
   if v.state=="DEPARTING":r.apply("finish_departure",[v.id])
  r.apply("tap",[2]);r.advance(0.75);r.advance(0,true)
 elif phase=="resume":
  check(r.session.data.clock==299.75 and r.session.data.shift.phase=="RUNNING","before-close fraction survives process exit")
  r.advance(0.25);check(r.session.data.shift.phase=="CLOSING","restart reaches17:00 once")
  r.advance(14.75)
  var visit={}
  for v in r.session.data.visits:
   if v.state=="WAITING":visit=v
  if visit.is_empty():check(false,"closing waiter absent");quit(1);return
  for station in range(3):
   var needed=r.session.cup.targets[station]-r.session.cup.taps[station]
   for n in range(needed):r.apply("tap",[station])
  r.apply("take_cup");check(r.apply("deliver",[r.session.data.cup_id,visit.id]),"closing delivery")
  r.advance(0.75);r.advance(0,true)
 elif phase=="collect":
  check(r.session.data.clock==315.5 and r.session.data.shift.phase=="CLOSING","payment-only closing survives restart")
  check(not r.apply("tap",[0]),"cooking closed after restart")
  if r.session.data.payments.is_empty():check(false,"last payment absent");quit(1);return
  var p=r.session.data.payments[0]
  check(absf(p.deadline-r.session.data.clock-11.25)<0.000001,"payment remainder retained")
  r.advance(11);check(r.apply("collect",[p.id]),"last coins collected before deadline")
  check(r.session.data.shift.phase=="SUMMARY" and r.session.data.money==p.amount,"summary uses exact collected amount")
 elif phase=="verify":
  check(r.session.data.shift.phase=="SUMMARY" and r.session.data.money==r.session.data.shift.stats.earned,"summary survives another process")
  var id=r.session.data.shift.summary_id
  check(r.apply("finish_summary",[id]) and not r.apply("finish_summary",[id]),"next day once after process restart")
  check(r.apply("start_shift",[2]) and Repo.new(path).session.data.visits.size()==1,"new day first visitor is not duplicated on load")
 else:check(false,"unknown probe phase")
 if failures==0:print("PASS: career process "+phase)
 quit(0 if failures==0 else 1)
