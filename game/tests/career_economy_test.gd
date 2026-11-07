extends SceneTree
const S=preload("res://orders/service.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func _init():
 var s=S.new(42);s.enable_career()
 if not s.has_method("enable_development"):print("FAIL: intermission economy missing");quit(1);return
 check(s.enable_development(),"enable new career economy")
 var e=s.data.economy;check(e.offers.size()==3 and e.offers[0]!=e.offers[1] and e.offers[1]!=e.offers[2],"three distinct offers")
 var before=s.snapshot()
 check(not s.buy_perk(e.offers[0],1) and before==s.snapshot(),"unaffordable choice changes nothing")
 s.data.money=200000;check(s.buy_perk(e.offers[0],1),"paid choice")
 before=s.snapshot();check(not s.buy_perk(e.offers[1],1) and not s.skip_perk(1) and before==s.snapshot(),"choice cannot repeat or skip afterwards")
 var copy=S.restore(JSON.parse_string(JSON.stringify(s.snapshot())))
 check(copy!=null and copy.data.economy==e,"offers and decisions stable on load")
 for station in ["grind","brew","milk","ads"]:
  for level in range(10):check(s.buy_equipment(station,level),"equipment "+station)
  check(not s.buy_equipment(station,10),"equipment max10")
 for module in ["heat","change","drive"]:check(s.buy_module(module) and not s.buy_module(module),"unique module ownership")
 check(s.equip_module("heat",0) and s.equip_module("change",1),"two slots")
 check(not s.equip_module("drive",2) and not s.equip_module("heat",1),"two slot limit and unique install")
 check(s.equip_module("drive",0),"replacement preserves collection")
 s.data.money=0;before=s.snapshot()
 check(not s.start_shift(1) and before==s.snapshot(),"maintenance cannot create debt")
 check(s.remove_module(0) and s.start_shift(1),"zero wallet remove paid module and continue")
 check(s.cup.targets[0]>=1 and s.cup.targets[1]>=1 and s.cup.targets[2]>=1,"minimum taps")
 check(not s.buy_module("heat") and not s.promote_league(0),"shop closed while running")
 s.advance(400);check(s.finish_summary(s.data.shift.summary_id),"next prep")
 check(s.data.economy.choice=="" and s.data.economy.active_perk=="" and not s.skip_perk(1) and s.skip_perk(2),"expiry and stale day guard")
 check(S.Schema.valid(s.snapshot()),"valid economy snapshot")
 if failures==0:print("PASS: choices, saved offers, limited equipment/modules and debt-free start")
 quit(0 if failures==0 else 1)
