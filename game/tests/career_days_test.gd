extends SceneTree
const Service=preload("res://orders/service.gd")
var failures=0
func check(ok: bool,text: String) -> void:
 if not ok:failures+=1;push_error(text)
func _init() -> void:
 var s=Service.new()
 if not s.has_method("enable_career"):
  print("FAIL: endless career days absent");quit(1);return
 check(s.enable_career(),"enable explicit career on an empty domain")
 check(not s.enable_career() and s.data.shift.day_number==1,"enable is not a reset button")
 check(s.data.shift.phase=="PREPARING" and s.clock_minutes()==480,"day starts at08:00 without wall date")
 check(not s.tap(0) and not s.spawn_visit(),"preparation pauses the cafe")
 var before=s.snapshot();s.advance(100000)
 check(s.snapshot()==before,"intermission has no active time")
 s.data.money=777;s.data.profiles["guest-01"].trust_l=0.8
 for day in range(1,101):
  check(s.start_shift(day),"each day starts without waiting for a real date")
  check(not s.start_shift(day),"double start rejected")
  check(s.clock_minutes()==480 and s.data.visits.size()==1,"start has a single first visitor")
  s.advance(299.5)
  check(s.clock_minutes()==1019,"clock before close is16:59")
  s.advance(0.5)
  check(s.data.shift.phase=="SUMMARY" and s.clock_minutes()==1020,"unserved guests finish by17:00; no infinite tail")
  check(s.data.money==777 and s.data.profiles["guest-01"].trust_l==0.8,"a poor day never erases wallet or drink trust")
  var id=s.data.shift.summary_id
  check(id>0 and not s.spawn_visit() and not s.tap(0),"summary is a paused terminal phase")
  check(s.finish_summary(id),"summary prepares exactly one next day")
  before=s.snapshot()
  check(not s.finish_summary(id) and not s.start_shift(day),"old summary/start cannot mutate new preparation")
  check(s.snapshot()==before and s.data.shift.day_number==day+1,"repeat taps do not increment day or draw forecasts")
 check(s.data.shift.day_number==101,"days6 and100 have no fixed career finale")
 var big=Service.new(123);var small=Service.new(123)
 big.enable_career();small.enable_career();big.start_shift(1);small.start_shift(1)
 big.advance(10000)
 for n in range(4000):small.advance(0.1)
 check(big.snapshot()==small.snapshot(),"large delta and small frames produce identical RNG/visits/history/day result")
 var schema=Service.Schema
 var replay=Service.new();replay.enable_career()
 var first_summary=0
 for day in range(1,4):
  replay.start_shift(day);replay.advance(300)
  if day==1:first_summary=replay.data.shift.summary_id
  if day<3:replay.finish_summary(replay.data.shift.summary_id)
 var bad=replay.snapshot();bad.shift.summary_id=first_summary
 check(not schema.valid(bad),"an earlier-day summary ID cannot be replayed as the current summary")
 bad=replay.snapshot();bad.shift.stats.earned=777
 check(not schema.valid(bad),"summary cannot report income with zero collected payments")
 if failures==0:print("PASS:100 consecutive days, exact clock, paused intermission, no resets/duplicate transitions, frame-independent bounded stream")
 quit(0 if failures==0 else 1)
