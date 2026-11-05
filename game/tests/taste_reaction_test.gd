extends SceneTree
const Session=preload("res://orders/session.gd")
func serve(extra: Array):
 var g=Session.new()
 for i in range(g.brew.targets.size()):
  for n in range(g.brew.targets[i]+extra[i]): assert(g.tap(i))
 assert(g.take_cup())
 assert(g.deliver(g.data.order.id,g.data.order.customer_id))
 return g
func _init() -> void:
 # A good average must not hide one badly overheated milk stage.
 var milk=serve([0,0,6])
 assert(is_equal_approx(milk.data.order.quality,0.8))
 assert("перегрет" in milk.data.profiles["guest-01"].last_reaction.to_lower(),"good average must still report overheated milk")
 var grind=serve([6,0,0])
 assert("горчит" in grind.data.profiles["guest-01"].last_reaction.to_lower(),"grinding defect must be recognisable")
 var brew=serve([0,8,0])
 assert("вяжет" in brew.data.profiles["guest-01"].last_reaction.to_lower(),"brewing defect must differ from grinding")
 var mixed=serve([2,3,7])
 assert(mixed.data.order.defects.size()==3)
 assert("перегрет" in mixed.data.profiles["guest-01"].last_reaction.to_lower(),"most severe defect determines the short reaction")
 var saved=Session.restore(mixed.snapshot())
 assert(saved.data.profiles["guest-01"].last_reaction==mixed.data.profiles["guest-01"].last_reaction)
 var ideal=serve([0,0,0])
 assert(ideal.data.profiles["guest-01"].last_reaction=="Вкусно!")
 print("PASS: stage-specific taste reaction, strongest mixed defect, good-average defect and saved reaction")
 quit()
