extends SceneTree
const Repo=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func _init():
 if not ResourceLoader.exists("res://persistence/legacy_candidate.gd"):print("FAIL: safe-boundary migration candidate absent");quit(1);return
 var C=load("res://persistence/legacy_candidate.gd")
 var count=0
 for name in DirAccess.get_files_at("res://tests/fixtures/v1"):
  if not name.ends_with(".json"):continue
  count+=1
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/"+name));var before=JSON.stringify(old)
  var result=C.convert(old,7)
  var active=old.order.state in ["BREWING","PAYMENT"] or old.get("shift",{}).get("mode","") in ["RUNNING","CLOSING"]
  check(JSON.stringify(old)==before,"source immutable "+name)
  if active:
   check(not result.ok and result.error=="LEGACY_SESSION_IN_PROGRESS","continue original phase "+name);continue
  check(result.ok,"convert boundary "+name)
  if not result.ok:continue
  var s=Repo.Service.restore(JSON.parse_string(JSON.stringify(result.snapshot)))
  check(s!=null,"candidate restores "+name)
  if s==null:continue
  var reward=200 if name=="summary.json" else 0
  check(s.data.money==old.money+3800+reward,"exact full refund and old premium "+name)
  check(s.data.upgrades.tuning==0 and s.data.upgrades.grace==0 and s.data.upgrades.grind==old.upgrades.grind,"compatible levels retained "+name)
  check(s.data.migration.candidate_only and s.data.migration.source_snapshot==old and s.data.migration.source_sequence==7,"source-bound receipt "+name)
  check(s.data.profiles["guest-01"].legacy_history==old.profiles["guest-01"].history and s.data.profiles["guest-01"].trust_l==0.5,"history preserved without invented trust")
  check(s.data.shift.phase=="PREPARING" and s.cup.is_empty() and s.data.visits.is_empty() and s.data.payments.is_empty(),"safe fresh preparation, no replayed coffee/money")
  check(not s.claim_legacy_reward(),"old premium already settled in candidate")
  check(s.start_shift(1),"candidate can exercise new career without live activation")
  s.advance(400);s.finish_summary(s.data.shift.summary_id)
  check(s.data.money==old.money+3800+reward and Repo.Service.Schema.valid(s.snapshot()),"candidate day transition never repeats migration credits")
  var bad=s.snapshot();bad.migration.refund+=1;check(not Repo.Service.Schema.valid(bad),"reject changed refund receipt")
  bad=s.snapshot();bad.migration.candidate_only="false";check(not Repo.Service.Schema.valid(bad),"candidate lifecycle flag must be boolean after accepted D16")
 check(count==13,"all13 original phase fixtures checked")
 var base=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/shop.json"))
 for tuning in range(4):
  for grace in range(3):
   base.upgrades.tuning=tuning;base.upgrades.grace=grace
   var actual=C.convert(base,1)
   var refund=[0,400,1200,2600][tuning]+[0,400,1200][grace]
   check(actual.ok and actual.snapshot.money==base.money+refund,"exact level refund matrix")
 base.money=2147483647
 check(not C.convert(base,1).ok,"wallet overflow fails without reset")
 check(not C.convert({},1).ok,"invalid external source rejected")
 if failures==0:print("PASS:13 phase fixtures,12 refund combinations, immutable history, reward/no replay and candidate receipt guards")
 quit(0 if failures==0 else 1)
