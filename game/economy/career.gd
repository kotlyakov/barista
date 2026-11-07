extends RefCounted
# Starting calibration042-1. No UI, real-money purchases or income simulator.
const Cup=preload("res://brewing/cup.gd")
const PERKS={
 "warmth":{"name":"Тёплые стаканы","price":100,"description":"Остывание в 1,5 раза медленнее. Только следующая смена."},
 "change":{"name":"Размен приготовлен","price":80,"description":"Ещё 6 секунд на сбор монет. Только следующая смена; автосбора нет."},
 "aroma":{"name":"Аромат на улицу","price":60,"description":"Интервал входа ×0.85, минимум 6 с. Только следующая смена."},
 "focus":{"name":"Рабочий ритм","price":120,"description":"На 1 тап помола меньше. Только следующая смена; минимум 1."}}
const MODULES={
 "heat":{"name":"Термостаканы","price":600,"maintenance":0,"description":"Остывание в 2 раза медленнее; действует при установке."},
 "change":{"name":"Поднос для монет","price":450,"maintenance":0,"description":"Ещё 8 секунд на сбор монет; действует при установке."},
 "drive":{"name":"Быстрый привод","price":800,"maintenance":50,"description":"На 2 тапа помола меньше; 50 монет при старте смены. Можно бесплатно снять."}}
const EQUIPMENT_PRICES=[400,800,1400,1900,2500,3200,4000,4900,5900,7000]
const GOAL_TARGETS=[3,6]
const GOAL_REWARDS=[100,200]
const LEAGUE_FAME=[0,30,100]
const LEAGUE_PRICE=[1.0,1.15,1.30]
const LEAGUE_FLOW=[1.0,0.90,0.80]
const EVENTS={
 "calm":"Обычный день: базовый поток и цены.","rain":"Дождь: интервал входа ×1.2.",
 "regulars":"Встреча постоянников: вес любимого напитка 4 вместо 2.",
 "festival":"Фестиваль: интервал ×0.85; цены ×1.10.",
 "milk":"Молочный день: вес молочных пожеланий ×2, их цена ×1.10.",
 "critic":"Критик: первый гость занимает обычное место; цена ×1.5, при J≥90 ещё 5 известности."}
static func make() -> Dictionary:
 var goals={};var claimed={};var gifts={}
 for n in range(6):
  var id="guest-%02d"%(n+1);goals[id]=0;claimed[id]=0;gifts[id]=false
 return {"version":1,"offers":[],"choice":"","active_perk":"","owned_modules":[],"equipped_modules":["",""],"goals":goals,"claimed":claimed,"gifts":gifts,"fame":0,"league":0,"critic_spawned":false}
static func offers(session) -> void:
 var rng=RandomNumberGenerator.new();rng.state=int(session.data.rng_state)
 var pool=PERKS.keys();var chosen=[]
 for n in range(3):
  var index=rng.randi_range(0,pool.size()-1);chosen.append(pool[index]);pool.remove_at(index)
 session.data.economy.offers=chosen;session.data.rng_state=str(rng.state)
static func effects(data: Dictionary) -> Dictionary:
 var result={"heat":1.0,"coins":12.0,"grind":0,"flow":1.0,"maintenance":0}
 if not data.has("economy"):return result
 var e=data.economy
 var perk=e.active_perk if data.shift.phase!="PREPARING" else ("" if e.choice=="skip" else e.choice)
 if perk=="warmth":result.heat*=1.5
 if perk=="change":result.coins+=6
 if perk=="aroma":result.flow*=0.85
 if perk=="focus":result.grind+=1
 for module in e.equipped_modules:
  if module=="heat":result.heat*=2
  if module=="change":result.coins+=8
  if module=="drive":result.grind+=2;result.maintenance+=50
 result.flow*=LEAGUE_FLOW[int(e.league)]*pow(0.95,int(data.upgrades.ads))
 if data.shift.event_id=="festival":result.flow*=0.85
 if data.shift.event_id=="rain":result.flow*=1.2
 result.flow*=1.0-0.05*int(e.claimed["guest-02"])
 return result
static func targets(data: Dictionary,recipe: String) -> Array:
 var result=Cup.TARGETS[recipe].duplicate();var effect=effects(data)
 for n in range(3):result[n]=maxi(1,int(result[n])-int(data.upgrades[Cup.STATIONS[n]])-(int(effect.grind) if n==0 else 0))
 return result
static func base_price(data: Dictionary,recipe: String,critic: bool) -> int:
 var base={"espresso":50,"cappuccino":80,"latte":90}[recipe]
 if not data.has("economy"):return base
 var factor=LEAGUE_PRICE[int(data.economy.league)]
 if data.shift.event_id=="festival" or (data.shift.event_id=="milk" and recipe!="espresso"):factor*=1.1
 if critic:factor*=1.5
 return int(floor(base*factor))
static func equipment_price(data: Dictionary,level: int) -> int:
 return int(ceil(EQUIPMENT_PRICES[level]*(1.0-0.05*int(data.economy.claimed["guest-01"]))))
static func maximum_receipt(data: Dictionary) -> int:
 return int(floor(base_price(data,"latte",data.get("shift",{}).get("event_id")=="critic")*1.2))
static func valid(e,data: Dictionary) -> bool:
 if not e is Dictionary or e.size()!=12 or not data.has("shift") or not data.has("upgrades") or data.has("legacy") or data.has("career"):return false
 if not data.shift is Dictionary or not data.shift.get("phase") in ["PREPARING","RUNNING","CLOSING","SUMMARY"] or not data.shift.get("event_id") in EVENTS:return false
 if e.get("version")!=1 or not e.get("offers") is Array or e.offers.size()!=3:return false
 var unique=[]
 for item in e.offers:
  if not item in PERKS or item in unique:return false
  unique.append(item)
 if not e.get("choice") is String or not e.choice in ["","skip"]+e.offers or not e.get("active_perk") is String:return false
 if not e.get("critic_spawned") is bool or not Cup.whole(e.get("fame")) or not Cup.whole(e.get("league")) or e.league>2 or e.fame<LEAGUE_FAME[int(e.league)]:return false
 if data.shift.phase!="PREPARING" and e.choice=="":return false
 if e.critic_spawned!=(data.shift.event_id=="critic" and data.shift.phase!="PREPARING"):return false
 var active="" if e.choice in ["","skip"] else e.choice
 if e.active_perk!=("" if data.shift.phase=="PREPARING" else active):return false
 if not e.get("owned_modules") is Array or not e.get("equipped_modules") is Array or e.equipped_modules.size()!=2:return false
 unique=[]
 for item in e.owned_modules:
  if not item in MODULES or item in unique:return false
  unique.append(item)
 unique=[]
 for item in e.equipped_modules:
  if item=="":continue
  if not item in e.owned_modules or item in unique:return false
  unique.append(item)
 for field in ["goals","claimed","gifts"]:
  if not e.get(field) is Dictionary or e[field].size()!=6:return false
 var total_goals=0
 for n in range(6):
  var key="guest-%02d"%(n+1)
  if not Cup.whole(e.goals.get(key)) or e.goals[key]>6 or not Cup.whole(e.claimed.get(key)) or e.claimed[key]>2 or not e.gifts.get(key) is bool:return false
  total_goals+=int(e.goals[key])
  if e.claimed[key]>0 and e.goals[key]<GOAL_TARGETS[int(e.claimed[key])-1]:return false
 if total_goals>e.fame:return false
 if data.upgrades.tuning!=0 or data.upgrades.grace!=0:return false
 return true
