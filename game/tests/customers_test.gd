extends SceneTree
func _init() -> void:
 var script=load("res://customers/roster.gd")
 if script==null:
  push_error("FAIL: persistent customer roster missing")
  quit(1)
  return
 var roster=script.new(123)
 assert(roster.profiles.size()==6)
 roster.profiles["guest-01"].relationship=-100
 roster.profiles["guest-02"].relationship=100
 assert(roster.weight("guest-01")==0.25 and roster.weight("guest-02")==2.0)
 var counts={}
 for n in range(6000):
  var id=roster.pick()
  counts[id]=counts.get(id,0)+1
 assert(counts["guest-01"]>0 and counts["guest-02"]>counts["guest-01"]*3)
 var a=script.new(99)
 var b=script.new(99)
 for n in range(30): assert(a.pick()==b.pick())
 var state=a.rng_state()
 var next=a.pick()
 a.set_rng_state(state)
 assert(a.pick()==next)
 assert(roster.profiles["guest-01"].mood=="neutral")
 print("PASS: six placeholder IDs, bounded weights, return possibility, seeded selection, RNG restore")
 quit(0)
