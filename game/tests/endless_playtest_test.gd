extends SceneTree
const Service=preload("res://orders/service.gd")
var failures=0

func check(condition: bool,message: String) -> void:
 if not condition:
  failures+=1
  push_error(message)

func configured(day: int,maxed: bool,seed_value: int):
 var game=Service.new(seed_value)
 game.enable_career()
 game.enable_development()
 if day>1:
  game.data.shift=Service.CareerShift.make(day,"calm",1)
  game.data.shift.stats.gifted=0
  game.data.cup_id=2
  game.data.next_id=3
 if maxed:
  for id in ["grind","brew","milk","ads"]:game.data.upgrades[id]=10
  game.data.economy.passives={}
  for id in game.Career.PASSIVE_IDS:game.data.economy.passives[id]=5
  game.data.economy.owned_modules=["drive","heat"]
  game.data.economy.equipped_modules=["drive","heat"]
  game.data.economy.fame=100
  game.data.economy.league=2
  for profile in game.data.profiles.values():profile.visits=20
  game.data.money=100
  game.configure_cup()
 return game

func clear_finished(game) -> void:
 for visit in game.data.visits.duplicate():
  if visit.state=="DEPARTING":game.finish_departure(visit.id)

func simulated_shift(game,pace: float) -> Dictionary:
 var day: int=game.data.shift.day_number
 if not game.start_shift(day):return {}
 var maximum_queue=0
 var rush_queue=0
 var rush_samples=0
 while game.data.shift.phase in ["RUNNING","CLOSING"]:
  clear_finished(game)
  if game.data.shift.phase=="SUMMARY":break
  var waiting=game.data.visits.filter(func(v):return v.state=="WAITING")
  maximum_queue=maxi(maximum_queue,waiting.size())
  if game.Career.in_rush(day,game.data.clock-game.data.shift.started_at):
   rush_queue+=waiting.size()
   rush_samples+=1
  if waiting.is_empty():
   game.advance(1)
   continue
  var guest: Dictionary=waiting[0]
  var recipe: String=guest.wish_recipe
  if not game.select_recipe(recipe):
   game.advance(1)
   continue
  var cup_id: int=game.data.cup_id
  var stations=[0,1] if recipe=="espresso" else [0,1,2]
  var elapsed=2.2
  for station in stations:elapsed+=game.cup.targets[station]/pace
  game.advance(elapsed)
  if game.data.shift.phase=="SUMMARY" or game.find_visit(guest.id).get("state")!="WAITING":continue
  for station in stations:
   for n in range(game.cup.targets[station]):game.tap(station)
  game.take_cup()
  if game.deliver(cup_id,guest.id):
   game.collect(game.data.payments.back().id)
  else:
   game.return_cup()
   game.advance(1)
 check(Service.Schema.valid(game.snapshot()),"simulated shift summary is reloadable")
 var stats: Dictionary=game.data.shift.stats.duplicate()
 stats.peak_queue=maximum_queue
 stats.rush_queue=snappedf(float(rush_queue)/maxi(1,rush_samples),.01)
 return stats

func _init() -> void:
 var game=configured(1,false,77)
 for day in range(1,501):
  var wallet: int=game.data.money
  check(game.start_shift(day),"start day "+str(day))
  game.advance(400)
  check(game.data.shift.phase=="SUMMARY","reach summary "+str(day))
  check(game.data.money==wallet and Service.Schema.valid(game.snapshot()),"poor shift preserves money and valid state")
  if day%25==0:
   game=Service.restore(JSON.parse_string(JSON.stringify(game.snapshot())))
   if game==null:
    push_error("Roundtrip at shift "+str(day));quit(1);return
  check(game.finish_summary(game.data.shift.summary_id),"advance to next day")
 check(game.data.shift.day_number==501,"no finale through 500 shifts")
 var old=configured(31,false,12)
 old.start_shift(31)
 old.data.shift.erase("market_rules")
 var guest: Dictionary=old.data.visits[0]
 old.select_recipe(guest.wish_recipe)
 for station in [0,1,2]:
  for n in range(old.cup.targets[station]):old.tap(station)
 old.take_cup()
 check(old.deliver(old.data.cup_id,guest.id),"legacy-priced pending drink")
 var loaded=Service.restore(JSON.parse_string(JSON.stringify(old.snapshot())))
 check(loaded!=null,"legacy active sale snapshot opens")
 if loaded!=null:
  check(loaded.data.payments[0].base==old.data.payments[0].base and loaded.data.payments[0].deadline==old.data.payments[0].deadline,"old amount and deadline stay fixed")
 var slow=simulated_shift(configured(1,false,45),1.6)
 check(slow.served>0 and slow.earned>=400,"new player can afford first equipment with service")
 print("BALANCE day=1 pace=1.6 ",JSON.stringify(slow))
 for day in [1,6,31,90,1000]:
  for rate in [1.6,3.0,8.0]:
   var total_served=0
   var total_earned=0
   var total_left=0
   var peak_queue=0
   var mean_rush=0.0
   for seed_value in range(5):
    var result=simulated_shift(configured(day,day>=31,seed_value+80),rate)
    total_served+=result.served
    total_earned+=result.earned
    total_left+=result.left
    peak_queue=maxi(peak_queue,result.peak_queue)
    mean_rush+=result.rush_queue
   print("BALANCE day=",day," pace=",rate," served=",total_served/5.0," earned=",total_earned/5.0," left=",total_left/5.0," peak=",peak_queue," rush_queue=",snappedf(mean_rush/5.0,.01))
   if day>=31 and rate==3.0:check(peak_queue>=3,"full upgrades still build a late rush queue")
   if day>=31 and rate==8.0:check(peak_queue>=2 and total_left==0,"expert rush has pressure and remains manageable")
 if failures==0:print("PASS: 500 consecutive shifts, 20 reloads, 76 economy and difficulty simulations")
 quit(0 if failures==0 else 1)
