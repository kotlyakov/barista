extends SceneTree
const Repo=preload("res://persistence/repository_v2.gd")
func fail(text: String) -> void:
 print("FAIL: "+text);quit(1)
func _init() -> void:
 var args=OS.get_cmdline_user_args()
 if args.size()!=2:fail("probe arguments");return
 var r=Repo.new(args[1])
 if not r.ready:fail(r.error);return
 if args[0]=="write":
  r.apply("spawn_visit",["guest-01","cappuccino"])
  for station in range(3):
   for n in range(r.session.cup.targets[station]):r.apply("tap",[station])
  r.advance(0.875);r.apply("take_cup");r.apply("deliver",[r.session.data.cup_id,r.session.data.visits[0].id])
  r.apply("tap",[2]);r.advance(0.75);r.advance(0,true)
 elif args[0]=="resume":
  if r.session.data.clock!=1.625:fail("background lost fractional clock");return
  if r.session.cup.temperature(r.session.data.clock)!=1.0/9.0:fail("background lost fractional heat interval");return
  if r.session.data.payments[0].deadline-r.session.data.clock!=11.25:fail("background lost payment remainder");return
  var payment=r.session.data.payments[0].id
  r.advance(0.25)
  if r.session.cup.temperature(r.session.data.clock)!=0:fail("heat boundary reset at restart");return
  if not r.apply("collect",[payment]) or r.apply("collect",[payment]):fail("payment replay");return
 elif args[0]=="verify":
  if r.session.data.money!=80 or r.session.data.profiles["guest-01"].visits!=1 or r.session.data.clock!=1.875:fail("repeated process restart changed wallet/history/clock");return
 else:fail("unknown probe phase");return
 print("PASS: separate process "+args[0]);quit()
