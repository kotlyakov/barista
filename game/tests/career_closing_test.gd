extends SceneTree
const Service=preload("res://orders/service.gd")
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok:failures+=1;push_error(text)
func closing_case():
 var s=Service.new();s.enable_career();s.start_shift(1);s.advance(299)
 for v in s.data.visits.duplicate():
  if v.state=="DEPARTING":s.finish_departure(v.id)
 return s
func _init() -> void:
 if not Service.new().has_method("enable_career"):
  print("FAIL: bounded closing absent");quit(1);return
 var s=closing_case()
 var waiting=[]
 for v in s.data.visits:
  if v.state=="WAITING":waiting.append(v.id)
 check(waiting.size()==1,"a freed full-cafe slot checks the next arrival once")
 s.advance(1)
 check(s.data.shift.phase=="CLOSING" and not s.spawn_visit(),"entry closes at exactly17:00")
 var before=s.snapshot();s.advance(50,true)
 check(s.snapshot()==before,"closing/payment/heat remain paused")
 s.advance(14.999)
 check(s.tap(0) and s.take_cup(),"last working cup can still be completed within15s")
 check(s.deliver(s.data.cup_id,waiting[0]),"delivery just before closing cutoff succeeds")
 var payment=s.data.payments[0].duplicate(true)
 check(absf(payment.deadline-s.data.clock-12)<0.000001,"new payment retains its own12-second deadline")
 s.advance(0.001)
 check(s.data.shift.phase=="CLOSING" and not s.tap(2) and not s.take_cup(),"after315s no evening cooking loop")
 s.advance(11.998)
 check(s.collect(payment.id),"coins can be collected after cooking has closed")
 check(s.data.shift.phase=="SUMMARY" and s.data.money==payment.amount,"last paid guest completes day without automatic money")
 check(s.data.shift.stats.earned==payment.amount and s.data.shift.stats.collected==1,"summary counts real collections")
 var expired=closing_case();expired.advance(15.999)
 var v={}
 for guest in expired.data.visits:
  if guest.state=="WAITING":v=guest
 check(not v.is_empty(),"waiting guest still has closing remainder")
 expired.tap(2);expired.take_cup();expired.deliver(expired.data.cup_id,v.id)
 expired.advance(10000)
 check(expired.data.shift.phase=="SUMMARY" and expired.data.clock<327,"huge delta stops at final finite payment deadline")
 check(expired.data.money==0 and expired.data.shift.stats.expired==1,"missed final coins are not awarded by summary")
 var no_drink=closing_case();no_drink.advance(16)
 check(no_drink.data.shift.phase=="SUMMARY" and no_drink.data.clock==315,"waiting budgets capped by15s closing, not endless completion")
 var simultaneous=closing_case();simultaneous.data.shift.next_arrival_at=300.0
 var count=simultaneous.data.next_id;simultaneous.advance(1)
 check(simultaneous.data.next_id==count,"at17:00 closing takes precedence over a scheduled arrival")
 var orphan=closing_case();orphan.advance(15.5)
 var id=orphan.data.visits[0].id
 orphan.tap(2);orphan.take_cup();orphan.deliver(orphan.data.cup_id,id)
 check(not orphan.tap(2) and not orphan.take_cup(),"payment-only closing cannot begin an orphan cup")
 var held=closing_case();held.spawn_visit();held.advance(15.5)
 var customer=held.data.visits[0].id
 held.tap(2);held.take_cup();held.deliver(held.data.cup_id,customer)
 var pending=held.data.payments[0].duplicate(true)
 held.tap(0);held.take_cup();check(held.cup.carrying,"remaining guest permits a legitimate final cup")
 held.advance(1)
 check(not held.cup.carrying and not held.tap(1),"hard315s cutoff returns held cup and closes cooking")
 check(held.collect(pending.id) and held.data.money==pending.amount,"returning unfinished cup does not cancel another guest's payment")
 var malformed=closing_case();malformed.advance(1)
 var snapshot=malformed.snapshot()
 snapshot.clock=302.0;snapshot.visits[0].arrived_at=302.0;snapshot.visits[0].bubble_until=302.0
 check(not Service.Schema.valid(snapshot),"persisted closing cannot contain a newly admitted after-hours guest")
 snapshot=malformed.snapshot();snapshot.visits=[];snapshot.payments=[]
 check(not Service.Schema.valid(snapshot),"empty closing must already be summary")
 if failures==0:print("PASS: exact17:00, closing15s, independent last payments, expiry/no autocollect, paused close and chronological boundary precedence")
 quit(0 if failures==0 else 1)
