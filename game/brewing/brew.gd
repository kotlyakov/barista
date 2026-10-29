extends RefCounted
const TARGETS = {"espresso":[12,16],"cappuccino":[12,16,10],"latte":[12,16,14]}
const DAMAGE = [0.08,0.06,0.10]
const DEFECTS = ["grind_bitter","brew_astringent","milk_overheated"]
var recipe: String
var targets: Array
var taps: Array = []
var stage = 0
var grace = 0
var damage_scale = 1.0
var locked = false
func _init(recipe_id = "cappuccino", target_override: Array = [], safe_extra = 0, scale = 1.0) -> void:
 assert(TARGETS.has(recipe_id))
 recipe = recipe_id
 targets = (TARGETS[recipe] if target_override.is_empty() else target_override).duplicate()
 assert(targets.size()==TARGETS[recipe].size())
 for n in targets: assert(n>=1)
 taps.resize(targets.size())
 taps.fill(0)
 grace = maxi(0,safe_extra)
 damage_scale = maxf(0,scale)
func complete(index: int) -> bool:
 return index>=0 and index<targets.size() and taps[index]>=targets[index]
func ready() -> bool:
 for index in range(targets.size()):
  if not complete(index): return false
 return true
func tap(index: int) -> bool:
 if locked or index<stage or index<0 or index>=targets.size(): return false
 if index>stage and (index!=stage+1 or not complete(stage)): return false
 stage=index
 taps[index]+=1
 return true
func qualities() -> Array:
 var values=[]
 for index in range(targets.size()):
  values.append(maxf(0,1-DAMAGE[index]*damage_scale*maxi(0,taps[index]-targets[index]-grace)))
 return values
func quality() -> float:
 var values=qualities()
 var total=0.0
 for value in values: total+=value
 return total/values.size()
func defects() -> Dictionary:
 var result={}
 var values=qualities()
 for index in range(values.size()):
  if values[index]<1: result[DEFECTS[index]]=1-values[index]
 return result
func take_cup() -> bool:
 if locked or not ready(): return false
 locked=true
 return true
func snapshot() -> Dictionary:
 return {"recipe":recipe,"targets":targets.duplicate(),"taps":taps.duplicate(),"stage":stage,"grace":grace,"damage_scale":damage_scale,"locked":locked}
static func restore(data: Dictionary):
 var b = load("res://brewing/brew.gd").new(data.recipe,data.targets,int(data.grace),float(data.damage_scale))
 b.taps=data.taps.duplicate()
 for index in range(b.targets.size()):
  b.targets[index]=int(b.targets[index])
  b.taps[index]=int(b.taps[index])
 b.stage=int(data.stage)
 b.locked=bool(data.locked)
 return b
