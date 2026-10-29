extends SceneTree
const Session=preload("res://orders/session.gd")
const Shift=preload("res://shift/shift.gd")
func _init() -> void:
 var a=Shift.new(1000000,180)
 if not a.data.has("offers"):
  push_error("FAIL: daily run offers missing")
  quit(1)
  return
 var b=Shift.new(1000000,180)
 assert(a.data.offers==b.data.offers and a.data.event==b.data.event)
 assert(a.data.offers.size()==3 and a.data.offers[0]!=a.data.offers[1] and a.data.offers[1]!=a.data.offers[2] and a.data.offers[0]!=a.data.offers[2])
 assert(not a.start(),"choose perk before start")
 assert(a.select_perk(a.data.offers[0]))
 assert(not a.select_perk(a.data.offers[1]),"cannot reroll selected perk")
 assert(a.start())
 var g=Session.new()
 g.enable_shift(1000000,180)
 g.shift.data.offers=["grind","brew","milk"]
 assert(g.choose_perk("grind"))
 assert(g.start_shift() and g.brew.targets[0]==10)
 var keep=g.data.profiles.duplicate(true)
 g.shift.data.mode="CLOSING"
 g.shift.finish(10,8)
 assert(g.collect_reward() and g.data.money==200)
 g.advance(0,false,1000000+86400)
 assert(g.shift.data.perk=="" and g.data.money==200 and g.data.profiles==keep)
 print("PASS: deterministic daily offers, one perk, parameters, reward once, temporary reset and permanent retention")
 quit(0)
