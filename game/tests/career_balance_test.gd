extends SceneTree
const S=preload("res://orders/service.gd")
const R=preload("res://persistence/repository_v2.gd")
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func setup(seed_value=1):
 var s=S.new(seed_value);s.enable_career();s.enable_development();s.data.money=100000;return s
func _init():
 if not S.new().has_method("enable_development"):print("FAIL: balance catalogue missing");quit(1);return
 var args=OS.get_cmdline_user_args()
 if args.size()==2:probe(args[0],args[1]);return
 # Every event/league/perk pair and both-slot set, including one paid module.
 for event in S.Career.EVENTS:
  for league in range(3):
   for perk in S.Career.PERKS:
    for pair in [["heat","change"],["heat","drive"],["change","drive"]]:
     var s=setup(league+1);s.data.shift.event_id=event;s.data.economy.fame=100;s.data.economy.league=league
     for profile in s.data.profiles.values():profile.visits=20
     s.data.economy.offers=S.Career.PERKS.keys().filter(func(k):return k!=perk).slice(0,2)+[perk]
     s.buy_perk(perk,1)
     for module in S.Career.MODULES:s.buy_module(module)
     s.equip_module(pair[0],0);s.equip_module(pair[1],1)
     for n in range(3):s.buy_equipment("ads",n)
     var before_start=s.data.money
     s.start_shift(1)
     check(s.data.money==before_start-(50 if "drive" in pair else 0),"exact maintenance for installed pair")
     check(s.cup.targets[0]==12-(2 if "drive" in pair else 0)-(1 if perk in ["focus","workflow","filter"] else 0),"exact grind target for combined drive/perk")
     check(S.Schema.valid(s.snapshot()),"combination valid at start")
     var clone=S.restore(JSON.parse_string(JSON.stringify(s.snapshot())))
     check(clone!=null,"combination JSON restore")
     var coins=S.Career.effects(s.data).coins
     for station in range(3):
      for n in range(s.cup.targets[station]):s.tap(station)
     var guest=s.data.visits[0]
     var original={"espresso":50,"cappuccino":80,"latte":90}[guest.wish_recipe]
     var factor=[1.0,1.15,1.3][league]
     if event=="festival" or (event=="milk" and guest.wish_recipe!="espresso"):factor*=1.1
     if event=="critic":factor*=1.5
     var expected_price=int(floor(original*factor))
     s.take_cup();s.deliver(s.data.cup_id,guest.id)
     check(s.data.payments[0].base==expected_price,"independent exact event/league price")
     check(s.data.payments[0].deadline==s.data.clock+coins and S.Schema.valid(s.snapshot()),"priced receipt valid in combination")
     s.advance(400);check(S.Schema.valid(s.snapshot()) and s.data.shift.phase=="SUMMARY","combination finite close")
 # Explicitly pin stacking/expiry and orphaned reservations with no automatic trust.
 var s=setup();s.data.economy.offers=["warmth","change","aroma"];s.buy_perk("warmth",1);s.buy_module("heat");s.equip_module("heat",0);s.start_shift(1)
 check(s.cup.cooling_seconds==3,"multiplicative cooling3sec maximum")
 s.advance(400);s.finish_summary(s.data.shift.summary_id);s.start_shift(2);check(s.cup.cooling_seconds==2,"one-day effect expires; permanent module remains")
 s=setup();s.data.economy.offers=["warmth","change","aroma"];s.buy_perk("change",1);s.buy_module("change");s.equip_module("change",0);s.start_shift(1)
 s.advance(299)
 for v in s.data.visits.duplicate():
  if v.state=="DEPARTING":s.finish_departure(v.id)
 s.advance(15.9)
 var receiver={}
 for v in s.data.visits:
  if v.state=="WAITING":receiver=v
 check(not receiver.is_empty(),"late guest waiting")
 if not receiver.is_empty():
  s.tap(0);s.take_cup();s.deliver(s.data.cup_id,receiver.id)
  check(s.data.payments.back().deadline>340 and S.Schema.valid(s.snapshot()),"latest26s payment supported through closing")
  s.advance(25.99);check(s.collect(s.data.payments.back().id),"latest receipt collectible")
 s=setup();s.reserve_gift("guest-01");s.start_shift(1)
 if not s.data.visits[0].customer_id=="guest-01":s.spawn_visit("guest-01")
 var trust=s.data.profiles["guest-01"].trust_l;s.advance(100)
 check(not s.data.economy.gifts["guest-01"] and s.data.profiles["guest-01"].trust_l==trust,"missed gift visit consumes reservation without trust")
 s=setup();s.data.economy.goals["guest-02"]=6;s.data.economy.fame=6;s.data.profiles["guest-02"].visits=6
 var original_flow=S.Career.effects(s.data).flow
 s.claim_goal("guest-02",0);check(is_equal_approx(S.Career.effects(s.data).flow,original_flow*0.95),"first friend connection5percent")
 s.claim_goal("guest-02",1);check(is_equal_approx(S.Career.effects(s.data).flow,original_flow*0.90),"second friend connection10percent")
 s.data.economy.goals["guest-01"]=6;s.data.economy.fame=12;s.data.profiles["guest-01"].visits=6
 s.claim_goal("guest-01",0);check(S.Career.equipment_price(s.data,0)==380,"first discount5percent")
 s.claim_goal("guest-01",1);check(S.Career.equipment_price(s.data,2)==1260,"second discount10percent")
 for speed in [0.12,0.28,0.8,-1.0]:play_shift(speed)
 var path="user://economy-process-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
 for phase in ["shop","start","finish","verify"]:
  var output=[]
  var code=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/career_balance_test.gd","--",phase,path],output,true)
  check(code==0 and not "ERROR:" in "\n".join(output) and "PASS:" in "\n".join(output),"economy process "+phase+" "+"\n".join(output))
 if failures==0:print("PASS:864 effect combinations, finite closing, real play calibration and four economy processes")
 quit(0 if failures==0 else 1)
func play_shift(seconds: float):
 var s=setup(73);s.data.money=0;s.skip_perk(1);s.start_shift(1)
 while s.data.shift.phase in ["RUNNING","CLOSING"]:
  for v in s.data.visits.duplicate():
   if v.state=="DEPARTING":s.finish_departure(v.id)
  var visit={}
  for v in s.data.visits:
   if v.state=="WAITING":visit=v;break
  if visit.is_empty() or not s.can_prepare():s.advance(0.1);continue
  s.select_recipe(visit.wish_recipe)
  if seconds<0:s.tap(0)
  else:
   for station in range(3 if visit.wish_recipe!="espresso" else 2):
    for n in range(s.cup.targets[station]):s.tap(station);s.advance(seconds)
  if s.take_cup() and s.deliver(s.data.cup_id,visit.id):
   if seconds>=0:s.collect(s.data.payments.back().id)
  else:s.return_cup()
  check(S.Schema.valid(s.snapshot()),"real-play persisted boundary")
 check(s.data.money==s.data.shift.stats.earned and S.Schema.valid(s.snapshot()),"calibration actual collected receipts only")
 print("CALIBRATION tap_seconds=",seconds," stats=",JSON.stringify(s.data.shift.stats)," wallet=",s.data.money)
func probe(phase: String,path: String):
 var r=R.new(path);check(r.ready,"process ready")
 if phase=="shop":
  r.apply("enable_career");r.apply("enable_development");r.session.data.money=2000;r.checkpoint()
  r.apply("buy_module",["drive"]);r.apply("equip_module",["drive",0]);r.apply("reserve_gift",["guest-01"])
  r.apply("buy_perk",[r.session.data.economy.offers[0],1])
 elif phase=="start":
  check(r.session.data.economy.choice!="" and r.session.data.economy.gifts["guest-01"],"shop decisions survive process")
  var money=r.session.data.money;check(r.apply("start_shift",[1]) and r.session.data.money==money-50,"maintenance once on start")
  r.advance(0.5);r.suspend()
 elif phase=="finish":
  var money=r.session.data.money;check(not r.apply("start_shift",[1]) and r.session.data.money==money,"restart does not repeat maintenance")
  r.advance(400);check(r.apply("finish_summary",[r.session.data.shift.summary_id]),"new day saved")
 elif phase=="verify":
  check(r.session.data.shift.day_number==2 and r.session.data.economy.active_perk=="" and r.session.data.economy.choice=="" and r.session.data.economy.owned_modules==["drive"],"permanent stays, temporary expires across processes")
 if failures==0:print("PASS: economy process "+phase)
 quit(0 if failures==0 else 1)
