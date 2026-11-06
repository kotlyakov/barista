extends SceneTree
const S=preload("res://orders/service.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func make(seed_value=1):
 var s=S.new(seed_value);s.enable_career();s.enable_development();s.data.money=20000;return s
func coffee(s,visit):
 s.select_recipe(visit.wish_recipe)
 for station in range(3 if visit.wish_recipe!="espresso" else 2):
  for n in range(s.cup.targets[station]):s.tap(station)
 s.take_cup();check(s.deliver(s.data.cup_id,visit.id),"delivery")
func _init():
 if not S.new().has_method("enable_development"):print("FAIL: career effects missing");quit(1);return
 var s=make();s.buy_module("heat");s.equip_module("heat",0);s.buy_module("change");s.equip_module("change",1)
 s.start_shift(1);var v=s.data.visits[0];s.select_recipe(v.wish_recipe)
 for i in range(3):
  for n in range(s.cup.targets[i]):s.tap(i)
 s.advance(2);check(s.cup.component_level(0,s.data.clock)==2,"heat module slows cooling without changing quality")
 s.take_cup();s.deliver(s.data.cup_id,v.id)
 var p=s.data.payments[0];check(p.deadline==s.data.clock+20,"change module finite +8 seconds")
 check(S.restore(JSON.parse_string(JSON.stringify(s.snapshot())))!=null,"modified deadlines and heat restore")
 s=make(8);var target=s.data.profiles.keys()[0];var trust=s.data.profiles[target].trust_l
 check(s.reserve_gift(target) and not s.reserve_gift(target),"one reserved gift per profile")
 check(s.data.profiles[target].trust_l==trust,"paying gift does not buy trust")
 s.start_shift(1)
 if s.find_visit(s.data.visits[0].id).customer_id!=target:check(s.spawn_visit(target,s.data.profiles[target].favorite),"gift guest enters")
 var gift={}
 for guest in s.data.visits:
  if guest.customer_id==target:gift=guest
 check(gift.get("gift",false) and not s.data.economy.gifts[target],"next visit consumes gift once")
 var money=s.data.money;coffee(s,gift)
 check(s.data.money==money and s.data.payments.back().amount==0 and s.data.payments.back().state=="COLLECTED","gift never produces paid money")
 check(s.data.economy.goals[target]==1 and s.data.economy.fame==1,"real good favorite earns progress")
 check(S.Schema.valid(s.snapshot()),"gift receipt and history valid")
 s=make(9);s.data.economy.goals[target]=3;s.data.profiles[target].visits=6;s.data.shift.event_id="critic"
 check(s.claim_goal(target,0) and not s.claim_goal(target,0),"goal paid once")
 s.data.economy.fame=30;check(s.data.economy.league==0 and s.promote_league(0) and not s.promote_league(0),"league voluntary and stale guarded")
 s.start_shift(1);check(s.data.visits[0].get("critic",false),"critic uses first existing slot")
 coffee(s,s.data.visits[0]);check(s.data.economy.fame==36,"critic success fame")
 var a=make(34);a.data.shift.event_id="festival";a.buy_equipment("ads",0);a.start_shift(1)
 var b=S.restore(a.snapshot());a.advance(400)
 for n in range(4000):b.advance(0.1)
 check(a.snapshot()==b.snapshot(),"effects preserve frame-independent bounded stream")
 for day in range(2,102):
  a.finish_summary(a.data.shift.summary_id);a.skip_perk(day);a.start_shift(day);a.advance(400)
  check(a.data.visits.size()<=5 and S.Schema.valid(a.snapshot()),"bounded day "+str(day))
 if failures==0:print("PASS: real effects, finite payments, gifts/goals/fame/critic,100 days and frame equivalence")
 quit(0 if failures==0 else 1)
