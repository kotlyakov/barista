extends SceneTree
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok:failures+=1;push_error(text)
func _init() -> void:
 if not ResourceLoader.exists("res://persistence/migrations.gd"):
  print("FAIL: review-only legacy conversion absent");quit(1);return
 var M=load("res://persistence/migrations.gd")
 var Schema=load("res://persistence/service_schema.gd")
 var Repo=load("res://persistence/repository_v2.gd")
 var Old=load("res://persistence/store.gd")
 var files=DirAccess.get_files_at("res://tests/fixtures/v1")
 check(files.size()>=12,"fixtures cover old order and shift phases")
 for name in files:
  if not name.ends_with(".json"):continue
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1/"+name))
  var before=JSON.stringify(old)
  if name=="payment.json":
   var malformed=old.duplicate(true);malformed.order.payment.base={}
   var rejected=M.preview(malformed)
   check(rejected.has("ok") and not rejected.ok,"malformed optional v1 payment fields return structured failure, not script error")
  var result=M.preview(old)
  check(result.ok and Schema.valid(result.snapshot),"converted fixture valid: "+name)
  if not result.ok:continue
  var v=result.snapshot
  check(JSON.stringify(old)==before,"converter leaves source bytes/data unchanged")
  check(v.money==old.money and v.upgrades==old.upgrades,"money and purchased levels preserved: "+name)
  check(v.profiles["guest-01"].relationship==old.profiles["guest-01"].relationship and v.profiles["guest-01"].trust_l==0.5,"old relationship is not fabricated L")
  check(v.legacy.review_only and v.legacy.source_snapshot==old,"all unknown legacy effects remain visible for policy review")
  var path="user://test-migrate-"+str(Time.get_ticks_usec())
  var original=Old.new(path);check(original.save(old).ok,"write genuine v1 slot")
  var bytes=FileAccess.get_file_as_bytes(path+"/slot0.json")
  check(not Repo.new(path).ready,"no automatic live legacy activation")
  var review=Repo.new(path,true)
  check(review.ready,"explicit review import into separate v2-review directory")
  check(FileAccess.get_file_as_bytes(path+"/slot0.json")==bytes,"v1 original remains byte-identical")
  check(FileAccess.get_file_as_bytes(path+"/v1-before-v2/slot0.json")==bytes,"immutable backup checked byte-for-byte")
  if not review.ready:continue
  var wallet=review.session.data.money
  var pending=review.session.data.payments
  if old.order.state=="PAYMENT":
   check(pending.size()==1 and pending[0].amount==old.order.payment.amount,"pending payment amount preserved")
   check(pending[0].deadline-review.session.data.clock==old.order.payment.deadline-old.clock,"pending payment remaining time preserved")
   var id=pending[0].id
   check(review.apply("collect",[id]),"legacy pending coins collected once")
   check(not review.apply("collect",[id]),"repeat legacy collection rejected")
   wallet+=old.order.payment.amount
  check(Repo.new(path,true).session.data.money==wallet,"restart does not reimport/regrant old state")
  if name=="summary.json":
   check(review.apply("claim_legacy_reward"),"old earned but uncollected premium retained")
   check(not review.apply("claim_legacy_reward") and Repo.new(path,true).session.data.money==wallet+200,"legacy premium has one persisted claim")
  if name=="brewing.json":
   check(review.session.cup.taps[0]==old.brew.taps[0] and review.session.cup.temperature(review.session.data.clock)==0,"counts retained, unknown old temperature explicitly cold in review")
   DirAccess.remove_absolute(ProjectSettings.globalize_path(path+"/slot0.json"))
   check(not Repo.new(path).ready,"backup/import evidence forbids silently initializing wallet zero when original is missing")
 if failures==0:print("PASS: all v1 phase fixtures, immutable backups, review-only import, wallet/upgrades/history/pending money and one-time reward")
 quit(0 if failures==0 else 1)
