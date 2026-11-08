extends SceneTree
const Bridge=preload("res://ui/session_bridge.gd")
func _init() -> void:call_deferred("run")
func run() -> void:
 var path="user://auto-milk-"+str(Time.get_ticks_usec())
 var b=Bridge.new(path)
 if not b.ready or not b.apply("start_shift",[1]) or not b.apply("add_milk"):
  push_error("Live repository must allow adding milk");quit(1);return
 if b.session.cup.contents()!="milk" or b.session.cup.milk_doses!=1:quit(1);return
 for i in range(11):
  if not b.apply("tap",[2]):quit(1);return
 if not b.apply("add_milk") or b.apply("add_milk"):quit(1);return
 if b.session.cup.component_level(1,0)<6:quit(1);return
 b=Bridge.new(path)
 if not b.ready or b.session.cup.milk_doses!=2 or b.session.cup.qualities()[2]>=1.0:quit(1);return
 for i in range(3):b.apply("tap",[2])
 if b.session.cup.qualities()[2]>=1.0:quit(1);return
 if not b.apply("tap",[0]) or not b.apply("tap",[1]) or b.session.cup.contents()!="latte":quit(1);return
 if not b.apply("discard_cup") or not b.session.cup.is_empty() or b.apply("tap",[2]):quit(1);return
 # v2.4 working cups retain their original recipe and contents through the upgrade.
 var old_path=path+"-old"
 var old=Bridge.V2.new(old_path)
 if not old.apply("enable_career") or not old.apply("enable_development") or not old.apply("start_shift",[1]):quit(1);return
 if not old.apply("select_recipe",["latte"]) or not old.apply("tap",[2]):quit(1);return
 var old_cup: Dictionary=old.session.cup.snapshot()
 var upgraded=Bridge.new(old_path)
 if not upgraded.ready or upgraded.session.cup.snapshot()!=old_cup or upgraded.apply("add_milk"):quit(1);return
 if not upgraded.apply("discard_cup") or upgraded.session.cup.milk_doses!=0:quit(1);return
 # Do not lose purchased steaming reductions or the warmth effect in an auto cup.
 var upgraded_cup=Bridge.V2.Service.new()
 upgraded_cup.enable_career();upgraded_cup.enable_development();upgraded_cup.enable_auto_recipe()
 upgraded_cup.data.money=10000
 if not upgraded_cup.buy_equipment("milk",0) or not upgraded_cup.buy_passive("warmth",0):quit(1);return
 upgraded_cup.start_shift(1)
 if not upgraded_cup.add_milk() or upgraded_cup.cup.targets[2]!=9:quit(1);return
 if not upgraded_cup.add_milk() or upgraded_cup.cup.targets[2]!=13 or not is_equal_approx(upgraded_cup.cup.cooling_seconds,1.1):quit(1);return
 if not Bridge.V2.Store.Schema.valid(upgraded_cup.snapshot()):quit(1);return
 print("PASS: milk doses, retained overheat, dilution, legacy cup and paid steaming/cooling effects")
 quit()
