extends SceneTree
var failures=0
var Cup
var Evaluation
func check(ok: bool, message: String) -> void:
 if not ok:
  failures+=1
  push_error(message)
func near(a: float, b: float) -> bool:
 return absf(a-b)<0.000001
func make_cup(recipe: String, taps: Array):
 var b=Cup.new(recipe)
 for station in range(3):
  for n in range(taps[station]): b.tap(station,0)
 return b
func score(b,wish="cappuccino",waited=0.0,patience=75.0,now=0.0) -> Dictionary:
 return Evaluation.evaluate(b.snapshot(),wish,waited,patience,now)
func _init() -> void:
 if not ResourceLoader.exists("res://brewing/cup.gd") or not ResourceLoader.exists("res://brewing/evaluation.gd"):
  print("FAIL: free cup evaluation is absent")
  quit(1)
  return
 Cup=load("res://brewing/cup.gd")
 Evaluation=load("res://brewing/evaluation.gd")
 if Cup==null or Evaluation==null: quit(1); return
 test_examples()
 test_recipe_matching()
 test_monotonicity_and_history()
 test_invalid_inputs()
 if failures==0: print("PASS: Q/J/C formulas, complete recipe matrix, defects, monotonicity, patience, invalid inputs")
 quit(0 if failures==0 else 1)

func test_examples() -> void:
 for row in [["cappuccino",[12,16,10],"cappuccino",0.0,100.0],
  ["cappuccino",[12,16,10],"cappuccino",9.0,25.0],
  ["cappuccino",[12,16,16],"cappuccino",0.0,54.208],
  ["cappuccino",[12,16,10],"latte",0.0,60.0],
  ["cappuccino",[0,0,10],"cappuccino",0.0,3.24],
  ["cappuccino",[1,1,1],"cappuccino",0.0,3.1662543402777774]]:
  var result=score(make_cup(row[0],row[1]),row[2],0,75,row[3])
  check(near(result.J,row[4]),"literal specification J example "+str(row))
 var e=score(make_cup("espresso",[12,16,0]),"espresso")
 check(near(e.Q,1) and near(e.J,100) and near(e.d,1),"espresso excludes absent optional milk")
 var missing=score(make_cup("cappuccino",[12,16,0]),"espresso")
 check(near(missing.Q,0.7) and missing.d==0 and missing.R==1,"missing required milk remains a Q defect even for espresso guest")
 var accidental=score(make_cup("espresso",[12,16,16]),"espresso")
 check(near(accidental.Q,0.82) and accidental.R==0.5,"real accidental milk affects Q and matching")
 check(near(score(make_cup("cappuccino",[11,16,10])).Q,0.9791666666666666),"grind weight")
 check(near(score(make_cup("cappuccino",[12,15,10])).Q,0.971875),"brew weight")
 check(near(score(make_cup("cappuccino",[12,16,9])).Q,0.97),"milk weight")

func test_recipe_matching() -> void:
 var wishes=["espresso","cappuccino","latte"]
 var fixtures=[
  ["espresso",[1,1,0],"espresso",[1.0,0.5,0.5]],
  ["cappuccino",[1,1,0],"espresso",[1.0,0.5,0.5]],
  ["latte",[1,1,0],"espresso",[1.0,0.5,0.5]],
  ["cappuccino",[1,1,1],"cappuccino",[0.5,1.0,0.5]],
  ["latte",[1,1,1],"latte",[0.5,0.5,1.0]],
  ["espresso",[1,1,1],"coffee_milk",[0.5,0.5,0.5]],
  ["cappuccino",[0,0,1],"milk",[0.0,0.0,0.0]],
  ["cappuccino",[1,0,1],"milk_grounds",[0.0,0.0,0.0]],
  ["latte",[1,0,0],"grounds",[0.0,0.0,0.0]],
  ["cappuccino",[22,26,20],"cappuccino",[0.5,1.0,0.5]]]
 for fixture in fixtures:
  var b=make_cup(fixture[0],fixture[1])
  for i in range(3):
   var result=score(b,wishes[i])
   check(result.contents==fixture[2] and result.R==fixture[3][i],"actual components determine R, not q or guest selection")
 var milk14=score(make_cup("cappuccino",[12,16,14]))
 check(milk14.contents=="cappuccino" and near(milk14.m,0.6),"14 milk taps do not rename damaged cappuccino to latte")

func test_monotonicity_and_history() -> void:
 var b=make_cup("cappuccino",[12,16,10])
 var quick=score(b)
 var slow=score(b,"cappuccino",37.5)
 var exhausted=score(b,"cappuccino",75)
 check(quick.W==1 and slow.W==0.5 and exhausted.W==0,"patience normalization")
 check(quick.J>slow.J and slow.J>exhausted.J,"waiting lowers impression")
 check(quick.C==slow.C and slow.C==exhausted.C,"waiting does not corrupt drink history C")
 for station in range(3):
  var previous=101.0
  for extra in range(12):
   var counts=[12,16,10]
   counts[station]+=extra
   var r=score(make_cup("cappuccino",counts))
   check(r.J<=previous and r.J>=0 and r.J<=100,"over-tap never improves impression")
   previous=r.J
  previous=-1
  var optimum=[12,16,10]
  for taps in range(optimum[station]+1):
   var counts=optimum.duplicate()
   counts[station]=taps
   var r=score(make_cup("cappuccino",counts))
   check(r.J>=previous,"repairing under-taps increases impression")
   previous=r.J
 var previous=101.0
 for second in range(11):
  var r=score(b,"cappuccino",0,75,second)
  check(r.J<=previous,"cooling cannot improve impression")
  previous=r.J
 var result=score(b)
 var copy=b.snapshot()
 Evaluation.evaluate(copy,"latte",10,75,2)
 check(copy==b.snapshot() and result.J==100,"evaluation is pure and does not mutate original cup")

func test_invalid_inputs() -> void:
 var b=make_cup("cappuccino",[12,16,10])
 check(Evaluation.evaluate({},"cappuccino",0,75,0).is_empty(),"invalid snapshot rejected")
 for args in [["water",0,75,0],["cappuccino",0,0,0],["cappuccino",-1,75,0],["cappuccino",NAN,75,0],["cappuccino",0,INF,0],["cappuccino",0,75,NAN],["cappuccino",0,75,-1]]:
  check(Evaluation.evaluate(b.snapshot(),args[0],args[1],args[2],args[3]).is_empty(),"invalid scoring input rejected")
