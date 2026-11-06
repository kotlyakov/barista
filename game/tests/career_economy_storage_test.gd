extends SceneTree
const R=preload("res://persistence/repository_v2.gd")
class Failure:
 extends RefCounted
 func save(_s,_n=-1):return {"ok":false,"error":"FORCED_WRITE"}
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func _init():
 if not R.Service.new().has_method("enable_development"):print("FAIL: persisted economy absent");quit(1);return
 var path="user://economy-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 var r=R.new(path);r.apply("enable_career");check(r.apply("enable_development"),"init persisted")
 r.session.data.money=20000;r.session.data.economy.goals["guest-01"]=3;r.session.data.economy.fame=100
 for profile in r.session.data.profiles.values():profile.visits=20
 r.checkpoint()
 for command in [["buy_perk",[r.session.data.economy.offers[0],1]],["skip_perk",[1]],["buy_equipment",["grind",0]],["buy_module",["heat"]],["reserve_gift",["guest-01"]],["claim_goal",["guest-01",0]],["promote_league",[0]],["start_shift",[1]]]:
  var before=r.session.snapshot();var healthy=r.store;r.store=Failure.new()
  check(not r.apply(command[0],command[1]) and r.session.snapshot()==before,"atomic rollback "+command[0]);r.store=healthy
 check(r.apply("buy_module",["drive"]) and r.apply("equip_module",["drive",0]),"module commands committed")
 check(r.apply("buy_perk",[r.session.data.economy.offers[0],1]),"choice committed")
 var reload=R.new(path);check(reload.ready and reload.session.snapshot()==r.session.snapshot(),"economy reload exact")
 check(not reload.apply("skip_perk",[1]) and reload.apply("start_shift",[1]),"saved decision and one start")
 var money=reload.session.data.money
 check(R.new(path).session.data.money==money and not reload.apply("start_shift",[1]),"maintenance not charged by reload")
 var malformed=reload.session.snapshot();malformed.economy.equipped_modules=["heat","change","drive"]
 check(not R.Store.Schema.valid(malformed),"reject corrupt slot count")
 malformed=reload.session.snapshot();malformed.economy.offers=["fake","fake","fake"]
 check(not R.Store.Schema.valid(malformed),"reject corrupt offers")
 malformed=reload.session.snapshot();malformed.economy.active_perk="fake"
 check(not R.Store.Schema.valid(malformed),"reject corrupt active effect")
 if failures==0:print("PASS: atomic economy commands, persisted decisions/maintenance and strict external snapshots")
 quit(0 if failures==0 else 1)
