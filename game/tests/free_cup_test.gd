extends SceneTree
var failures = 0
var Cup
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func close(a: float, b: float) -> bool:
 return absf(a-b)<0.000001
func _init() -> void:
 if not ResourceLoader.exists("res://brewing/cup.gd"):
  print("FAIL: independent free cup model is absent")
  quit(1)
  return
 Cup=load("res://brewing/cup.gd")
 if Cup==null: quit(1); return
 test_free_order()
 test_thresholds()
 test_return_and_heat()
 test_restore_validation()
 if failures==0: print("PASS: free cup, thresholds, recipes, composition, thermal clocks, editable return, snapshot validation")
 quit(0 if failures==0 else 1)

func test_free_order() -> void:
 var b=Cup.new()
 check(not b.can_take(),"empty cup cannot be picked up")
 check(not b.tap(1,0),"brewing without grounds must be rejected")
 check(b.taps==[0,0,0] and b.first_tap==-1,"rejected brewing creates no contents or recipe lock")
 check(b.select_recipe("latte"),"empty cup recipe can be changed")
 check(b.tap(2,0),"milk first is allowed")
 check(b.can_take() and b.contents()=="milk","one milk tap creates a takeable milk cup")
 check(b.pickup_line()=="Одно молоко!!!","milk pickup describes actual contents")
 check(not b.select_recipe("espresso"),"first accepted tap freezes recipe")
 check(not b.tap(1,0.1) and b.taps==[0,0,1],"rejected brewing preserves milk")
 check(b.tap(0,0.2) and b.contents()=="milk_grounds","grinding can follow milk")
 check(b.pickup_line()=="Кофе-то не сварила!","unbrewed coffee is not presented as ready")
 check(b.tap(1,0.3) and b.contents()=="latte","brewing requires only one grind tap")
 check(b.tap(0,0.4),"can return to any station before delivery")
 var dry=Cup.new()
 check(dry.tap(0,0) and dry.can_take(),"one grind tap creates takeable grounds")
 check(dry.contents()=="grounds" and dry.temperature(0)==0,"dry grounds have no liquid heat")
 check(dry.pickup_line()=="Тут же одни молотые зёрна!","dry cup describes contents")
 var e=Cup.new("espresso")
 check(e.targets==[12,16,10],"espresso retains target for accidentally added milk")
 check(e.tap(2,0),"espresso label does not prohibit milk")
 check(e.tap(0,0) and e.tap(1,0) and e.contents()=="coffee_milk","espresso plus milk has a distinct actual type")
 var targets=[1,1,1]
 var upgraded=Cup.new("latte",targets)
 targets[0]=10
 check(upgraded.tap(0,0) and upgraded.qualities()[0]==1,"target snapshot is independent and permits N=1")

func test_thresholds() -> void:
 # Independent expected values pin both under-tapping and all 10 over-tap steps.
 var under=[[0,0.0],[1,0.1],[2,0.2],[3,0.3],[4,0.4],[5,0.5],[6,0.6],[7,0.7],[8,0.8],[9,0.9],[10,1.0]]
 var over=[[11,0.9],[12,0.8],[13,0.7],[14,0.6],[15,0.5],[16,0.4],[17,0.3],[18,0.2],[19,0.1],[20,0.0],[21,0.0]]
 for station in range(3):
  for row in under+over:
   var b=Cup.new("cappuccino",[10,10,10])
   if station==1: b.tap(0,0)
   for n in range(row[0]): check(b.tap(station,0),"every eligible tap must count")
   check(b.taps[station]==row[0] and close(b.qualities()[station],row[1]),"exact under/over quality boundary")
 var b=Cup.new("cappuccino",[10,10,10])
 for n in range(21): b.tap(0,0)
 check(b.qualities()[0]==0 and b.tap(1,0),"zero-quality overground beans still permit brewing")
 var a=Cup.new("cappuccino",[10,10,10])
 for n in range(9): a.tap(0,0)
 var c=Cup.new("cappuccino",[10,10,10])
 for n in range(11): c.tap(0,0)
 check(close(a.qualities()[0],c.qualities()[0]),"under/over fixtures have equal numeric quality")
 check(a.defects().grind.kind=="under" and c.defects().grind.kind=="over","equal numeric quality retains different taste defects")
 check(a.defects().grind.description!=c.defects().grind.description,"taste descriptions distinguish under/over")

func test_return_and_heat() -> void:
 var b=Cup.new("cappuccino",[1,1,1])
 b.tap(0,0)
 b.tap(1,0.25)
 check(close(b.temperature(0.25),1),"full coffee heat starts at level1")
 check(b.take_cup() and not b.take_cup(),"one carrying cup at a time")
 check(not b.tap(2,0.5),"dragging pointer cannot operate a machine")
 var carried=Cup.restore(JSON.parse_string(JSON.stringify(b.snapshot())))
 check(carried!=null and carried.can_take(),"load returns transient carry to counter")
 check(close(carried.temperature(1.24),1),"save preserves fractional thermal interval")
 check(close(carried.temperature(1.25),8.0/9.0),"temperature decays on original boundary after reload")
 check(b.return_cup() and not b.return_cup(),"miss or cancel returns once")
 check(b.tap(2,2.5),"returned cup can receive missing milk")
 check(b.taps==[1,1,1] and close(b.temperature(2.5),1),"new milk heats only its own component")
 check(b.component_level(0,2.5)==3 and b.component_level(1,2.5)==1,"coffee and milk keep independent clocks")
 for n in range(10): b.tap(2,2.5)
 check(b.qualities()[2]==0 and b.temperature(2.5)==1,"overheated milk is hot but spoiled")
 check(b.temperature(11.5)==0,"9 seconds after last heat: no steam")
 check(b.tap(2,12) and b.taps[2]==12,"taps past N+10 continue counting")
 check(b.temperature(12)==1 and b.qualities()[2]==0,"extra heat does not repair over-tap damage")
 var before=b.snapshot()
 check(not b.tap(-1,12) and not b.tap(3,12) and not b.tap(0,NAN) and not b.tap(0,11),"invalid station/clock inputs are rejected")
 check(b.snapshot()==before,"invalid input cannot mutate cup")
 var cold=Cup.new()
 cold.tap(0,0)
 cold.tap(1,0)
 cold.tap(2,0)
 check(cold.component_level(0,0)==9 and cold.component_level(1,0)==9,"underheat starts with weak steam")
 check(close(cold.temperature(0),1.0/9.0) and cold.temperature(1)==0,"weak heat reaches cold after one second")

func test_restore_validation() -> void:
 for recipe in ["cappuccino","espresso","latte"]:
  var empty=Cup.new(recipe)
  var parsed=Cup.restore(JSON.parse_string(JSON.stringify(empty.snapshot())))
  check(parsed!=null,"empty cup with selected recipe survives JSON reload: "+recipe)
  if parsed!=null: check(parsed.recipe==recipe and not parsed.can_take(),"reloaded empty cup preserves selection and stays empty")
 var b=Cup.new()
 b.tap(0,0)
 var original=b.snapshot()
 var restored=Cup.restore(JSON.parse_string(JSON.stringify(original)))
 check(restored!=null and restored.snapshot()==original,"JSON roundtrip preserves counters and recipe")
 var detached=b.snapshot()
 detached.taps[0]=100
 check(b.taps[0]==1,"snapshot does not alias mutable state")
 for field in ["recipe","targets","taps","first_tap","last_tap","heat_start_level","heat_at"]:
  var missing=original.duplicate(true)
  missing.erase(field)
  check(Cup.restore(missing)==null,"missing snapshot field rejected: "+field)
 for value in [-1,0.5,INF,"1",true]:
  var malformed=original.duplicate(true)
  malformed.taps[0]=value
  check(Cup.restore(malformed)==null,"invalid counter rejected")
 var invalid=original.duplicate(true)
 invalid.taps[0]=0
 invalid.taps[1]=1
 check(Cup.restore(invalid)==null,"cannot restore coffee made without grounds")
 invalid=original.duplicate(true)
 invalid.heat_at[0]=0
 check(Cup.restore(invalid)==null,"absent component cannot have heat timestamp")
