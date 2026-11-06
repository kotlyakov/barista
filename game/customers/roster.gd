extends RefCounted
var profiles={}
var rng=RandomNumberGenerator.new()
static func defaults() -> Dictionary:
 var result={}
 var recipes=["cappuccino","espresso","latte"]
 for n in range(6):
  result["guest-%02d" % (n+1)]={"mood":"neutral","last_reaction":"","relationship":0,"visits":0,"history":[],"favorite":recipes[n%3]}
 return result
func _init(seed_value=1) -> void:
 profiles=defaults()
 rng.seed=seed_value
func weight(id: String) -> float:
 return clampf(1+float(profiles[id].relationship)/100.0,0.25,2.0)
func pick() -> String:
 return pick_available([])
func pick_available(excluded: Array) -> String:
 var available=[]
 var total=0.0
 for id in profiles:
  if id in excluded: continue
  available.append(id)
  total+=weight(id)
 if available.is_empty(): return ""
 var value=rng.randf()*total
 for id in available:
  value-=weight(id)
  if value<=0: return id
 return available.back()
func pick_recipe(id: String,milk_modifier=1.0) -> String:
 var choices=["espresso","cappuccino","latte"]
 var weights=[]
 var total=0.0
 for recipe in choices:
  var w=(2.0 if profiles[id].favorite==recipe else 1.0)*(milk_modifier if recipe!="espresso" else 1.0)
  weights.append(w)
  total+=w
 var value=rng.randf()*total
 for index in range(choices.size()):
  value-=weights[index]
  if value<=0: return choices[index]
 return choices.back()
func rng_state() -> String:
 # JSON numbers cannot preserve the exact signed 64-bit RNG state.
 return str(rng.state)
func set_rng_state(value: String) -> void:
 rng.state=int(value)
