extends RefCounted
# Free preparation model for v2. The v1 Session/Store still use brew.gd.
# All times are on the session's active clock; this model never reads wall time.
const TARGETS={"espresso":[12,16,10],"cappuccino":[12,16,10],"latte":[12,16,14]}
const STATIONS=["grind","brew","milk"]
const UNDER=[
 ["Не смолоты","Почти пустой, водянистый","Крупный помол, слабый вкус","Не хватает насыщенности","Почти подходящий"],
 ["Не сварено","Очень слабый, кисловатый","Недоваренный, тонкий","Недостаточно раскрыт","Почти сбалансированный"],
 ["Не обработано","Холодное, почти без пены","Чуть тёплое, слабая пена","Тёплое, рыхлая пена","Почти нужная текстура"]]
const OVER=[
 ["Лёгкая горчинка","Горьковатый","Заметно горький","Грубый","Резко горький","Едкий","Горько-сухой","Обжигающе горький","Нестерпимая горечь","Несъедобно горький"],
 ["Чуть терпковатый","Перезаваренный","Горьковато-терпкий","Вяжущий","Сухой, горький","Резко вяжущий","Жжёный привкус","Пепельный привкус","Угольная горечь","Кофейная гарь"],
 ["Чуть меньше сладости","Менее сладкое","Плоский вкус","Перегретое","Варёный привкус","Кипячёный привкус","Тяжёлый, неприятный вкус","Подгоревшее","Пригорелое","Горелое"]]
var recipe="cappuccino"
var targets: Array=[12,16,10]
var taps: Array=[0,0,0]
var first_tap=-1.0
var last_tap=-1.0
var heat_start_level: Array=[10,10]
var heat_at: Array=[-1.0,-1.0]
var carrying=false

func _init(recipe_id="cappuccino",target_override: Array=[]) -> void:
 var configured=select_recipe(recipe_id,target_override)
 assert(configured,"invalid cup configuration")

func is_empty() -> bool:
 return first_tap<0

func select_recipe(recipe_id: String,target_override: Array=[]) -> bool:
 if not is_empty() or not TARGETS.has(recipe_id): return false
 var values=TARGETS[recipe_id] if target_override.is_empty() else target_override
 if not values is Array or values.size()!=3: return false
 for value in values:
  if not whole(value,1): return false
 recipe=recipe_id
 targets=values.duplicate()
 for i in range(3): targets[i]=int(targets[i])
 return true

func tap(station: int,now: float) -> bool:
 if carrying or station<0 or station>2 or not finite_number(now,0) or now<last_tap: return false
 if station==1 and taps[0]==0: return false
 taps[station]+=1
 if first_tap<0: first_tap=now
 last_tap=now
 if station>0:
  var component=station-1
  var heat=clampf(float(taps[station])/targets[station],0,1)
  heat_start_level[component]=clampi(10-int(ceil(9*heat)),1,10)
  heat_at[component]=now
 return true

func qualities() -> Array:
 var values=[]
 for i in range(3):
  var t=int(taps[i])
  var n=int(targets[i])
  values.append(float(t)/n if t<=n else maxf(0,1-float(t-n)/10))
 return values

func defects() -> Dictionary:
 var result={}
 var q=qualities()
 for i in range(3):
  if q[i]==1: continue
  var t=int(taps[i])
  var n=int(targets[i])
  var kind="missing" if t==0 else "under" if t<n else "over"
  var level=mini(10,t-n) if kind=="over" else 0
  var band=0 if t==0 else mini(4,1+int(floor(4*float(t)/n)))
  var description=OVER[i][level-1] if kind=="over" else UNDER[i][band]
  result[STATIONS[i]]={"kind":kind,"level":level,"severity":1-q[i],"description":description}
 return result

func contents() -> String:
 if taps[1]>0:
  if taps[2]==0: return "espresso"
  return "coffee_milk" if recipe=="espresso" else recipe
 if taps[2]>0: return "milk_grounds" if taps[0]>0 else "milk"
 return "grounds" if taps[0]>0 else "empty"

func pickup_line() -> String:
 return {"milk":"Одно молоко!!!","grounds":"Тут же одни молотые зёрна!","milk_grounds":"Кофе-то не сварила!"}.get(contents(),"")

func can_take() -> bool:
 return not is_empty() and not carrying

func take_cup() -> bool:
 if not can_take(): return false
 carrying=true
 return true

func return_cup() -> bool:
 if not carrying: return false
 carrying=false
 return true

func component_level(component: int,now: float) -> int:
 if component<0 or component>1 or heat_at[component]<0: return 10
 return mini(10,int(heat_start_level[component])+int(floor(maxf(0,now-heat_at[component]))))

func temperature(now: float) -> float:
 if not finite_number(now,0): return 0
 return float(10-mini(component_level(0,now),component_level(1,now)))/9

func snapshot() -> Dictionary:
 # Carry is a transient gesture: load/cancel returns the same contents to the counter.
 return {"recipe":recipe,"targets":targets.duplicate(),"taps":taps.duplicate(),"first_tap":first_tap,"last_tap":last_tap,"heat_start_level":heat_start_level.duplicate(),"heat_at":heat_at.duplicate()}

static func finite_number(value,minimum=-1.0,maximum=1.0e12) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum

static func whole(value,minimum=0) -> bool:
 return finite_number(value,minimum,2147483647) and float(value)==floor(float(value))

static func valid(data) -> bool:
 if not data is Dictionary or not TARGETS.has(data.get("recipe")): return false
 for field in ["targets","taps","heat_start_level","heat_at"]:
  if not data.get(field) is Array: return false
 if data.targets.size()!=3 or data.taps.size()!=3 or data.heat_start_level.size()!=2 or data.heat_at.size()!=2: return false
 for i in range(3):
  if not whole(data.targets[i],1) or not whole(data.taps[i]): return false
 if data.taps[1]>0 and data.taps[0]==0: return false
 if not finite_number(data.get("first_tap")) or not finite_number(data.get("last_tap")): return false
 var empty=data.taps[0]==0 and data.taps[1]==0 and data.taps[2]==0
 if empty:
  if data.first_tap!=-1 or data.last_tap!=-1: return false
 elif data.first_tap<0 or data.last_tap<data.first_tap: return false
 for i in range(2):
  var station=i+1
  if not whole(data.heat_start_level[i],1) or data.heat_start_level[i]>10 or not finite_number(data.heat_at[i]): return false
  if data.taps[station]==0:
   if data.heat_at[i]!=-1 or data.heat_start_level[i]!=10: return false
  else:
   if data.heat_at[i]<data.first_tap or data.heat_at[i]>data.last_tap: return false
   var heat=clampf(float(data.taps[station])/data.targets[station],0,1)
   if data.heat_start_level[i]!=clampi(10-int(ceil(9*heat)),1,10): return false
 return true

static func restore(data: Dictionary):
 if not valid(data): return null
 var b=load("res://brewing/cup.gd").new(data.recipe,data.targets)
 for i in range(3): b.taps[i]=int(data.taps[i])
 b.first_tap=float(data.first_tap)
 b.last_tap=float(data.last_tap)
 for i in range(2):
  b.heat_start_level[i]=int(data.heat_start_level[i])
  b.heat_at[i]=float(data.heat_at[i])
 return b
