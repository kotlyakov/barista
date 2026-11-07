extends RefCounted
# Starting calibration042-1. No UI, real-money purchases or income simulator.
const Cup=preload("res://brewing/cup.gd")
const Shift=preload("res://shift/career_shift.gd")
const PERKS={
 "warmth":{"name":"Тёплые стаканы","price":100,"description":"Кофе остывает медленнее","art":"warmth","heat":1.5},
 "change":{"name":"Размен приготовлен","price":80,"description":"+6 секунд на сбор оплаты","art":"change","coins":6},
 "aroma":{"name":"Аромат на улицу","price":60,"description":"Гости приходят чаще","art":"aroma","flow":0.85},
 "focus":{"name":"Рабочий ритм","price":120,"description":"На 1 тап помола меньше","art":"focus","grind":1},
 "pressure":{"name":"Прогрев кофеварки","price":120,"description":"На 1 тап варки меньше","art":"focus","brew":1},
 "silky":{"name":"Тёплый питчер","price":120,"description":"На 1 тап молока меньше","art":"warmth","milk":1},
 "workflow":{"name":"Разложить инструменты","price":200,"description":"На 1 тап меньше на каждом приборе","art":"focus","grind":1,"brew":1,"milk":1},
 "quiet":{"name":"Тихий час","price":70,"description":"Гости приходят реже","art":"aroma","flow":1.18},
 "seats":{"name":"Стулья у окна","price":105,"description":"Гости ждут на 20% дольше","art":"aroma","patience":1.2},
 "notes":{"name":"Блокнот заказов","price":90,"description":"Заказ виден на 1,5 секунды дольше","art":"change","wish":1.5},
 "winter":{"name":"Термочехол","price":155,"description":"Медленнее остывает, гости дольше ждут","art":"warmth","heat":1.3,"patience":1.1},
 "tray":{"name":"Подготовить блюдца","price":155,"description":"+3 секунды на оплату, заказы видны дольше","art":"change","coins":3,"wish":1.0},
 "filter":{"name":"Настроить помол и пролив","price":170,"description":"На 1 тап меньше для помола и варки","art":"focus","grind":1,"brew":1},
 "steam":{"name":"Прогреть паровик","price":160,"description":"На 2 тапа молока меньше","art":"warmth","milk":2},
 "welcome":{"name":"Тёплая встреча","price":150,"description":"Гости приходят чаще и дольше ждут","art":"aroma","flow":0.93,"patience":1.12},
 "counter":{"name":"Свободная стойка","price":150,"description":"+4 секунды на оплату и на 1 тап варки меньше","art":"change","coins":4,"brew":1}}
const FEATURED={"calm":"focus","rain":"warmth","regulars":"welcome","festival":"change","milk":"steam","critic":"pressure"}
const MODULES={
 "heat":{"name":"Термостаканы","price":600,"maintenance":0,"description":"Остывание в 2 раза медленнее; действует при установке."},
 "change":{"name":"Поднос для монет","price":450,"maintenance":0,"description":"Ещё 8 секунд на сбор монет; действует при установке."},
 "drive":{"name":"Быстрый привод","price":800,"maintenance":50,"description":"На 2 тапа помола меньше; 50 монет при старте смены. Можно бесплатно снять."}}
const EQUIPMENT_PRICES=[400,800,1400,1900,2500,3200,4000,4900,5900,7000]
const PASSIVE_IDS=["tips","espresso","milk_income","fame","relationship","flow","patience","warmth","payment","wish"]
const PASSIVE_PRICES=[650,1200,2000,3100,4500]

static func passive_level(data: Dictionary,id: String) -> int:
 return int(data.get("economy",{}).get("passives",{}).get(id,0))

static func passive_factor(data: Dictionary,id: String,step: float) -> float:
 return 1.0+passive_level(data,id)*step

static func wish_seconds(data: Dictionary) -> float:
 return (3.0+float(ritual(data).get("wish",0.0)))*passive_factor(data,"wish",0.10)

static func patience_factor(data: Dictionary) -> float:
 return float(ritual(data).get("patience",1.0))*passive_factor(data,"patience",0.10)

static func ritual(data: Dictionary) -> Dictionary:
 var economy: Dictionary=data.get("economy",{})
 var key="choice" if data.get("shift",{}).get("phase")=="PREPARING" else "active_perk"
 return PERKS.get(economy.get(key,""),{})

static func tip_amount(data: Dictionary,base: int,relationship: int) -> int:
 return int(floor(base*(0.10+0.10*maxi(0,relationship)/100.0)*passive_factor(data,"tips",0.10)))

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
 var featured: String=FEATURED[session.data.shift.event_id]
 for n in range(3):
  var ticket=rng.randi_range(0,pool.size()-1+int(featured in pool))
  var index=pool.find(featured) if ticket==pool.size() else ticket
  chosen.append(pool[index])
  pool.remove_at(index)
 session.data.economy.offers=chosen;session.data.rng_state=str(rng.state)
static func effects(data: Dictionary) -> Dictionary:
 var result={"heat":1.0,"coins":12.0,"grind":0,"brew":0,"milk":0,"flow":1.0,"maintenance":0}
 if not data.has("economy"):return result
 var e=data.economy
 var perk=ritual(data)
 result.heat*=float(perk.get("heat",1.0))
 result.coins+=float(perk.get("coins",0.0))
 result.flow*=float(perk.get("flow",1.0))
 for station in Cup.STATIONS:result[station]+=int(perk.get(station,0))
 for module in e.equipped_modules:
  if module=="heat":result.heat*=2
  if module=="change":result.coins+=8
  if module=="drive":result.grind+=2;result.maintenance+=50
 result.flow*=LEAGUE_FLOW[int(e.league)]*pow(0.95,int(data.upgrades.ads))
 if data.shift.event_id=="festival":result.flow*=0.85
 if data.shift.event_id=="rain":result.flow*=1.2
 result.flow*=1.0-0.05*int(e.claimed["guest-02"])
 result.flow*=pow(0.97,passive_level(data,"flow"))
 result.heat*=passive_factor(data,"warmth",0.10)
 result.coins+=2.0*passive_level(data,"payment")
 return result
static func targets(data: Dictionary,recipe: String) -> Array:
 var result=Cup.TARGETS[recipe].duplicate();var effect=effects(data)
 for n in range(3):result[n]=maxi(1,int(result[n])-int(data.upgrades[Cup.STATIONS[n]])-int(effect[Cup.STATIONS[n]]))
 return result
static func market_step(day: int) -> int:
 return mini(5,maxi(0,floori((day-1)/5.0)))

static func purchase_price(data: Dictionary,base: int) -> int:
 return ceili(base*(100+5*market_step(int(data.shift.day_number)))/100.0)

static func sale_percent(day: int) -> int:
 return 3*market_step(day)

static func in_rush(day: int,elapsed: float) -> bool:
 var start=Shift.rush_start(day)
 return day>=6 and elapsed>=start and elapsed<start+60.0

static func arrival_interval(data: Dictionary,elapsed: float) -> float:
 var day: int=data.shift.day_number
 var flow: float=effects(data).flow
 if data.shift.get("market_rules",0)!=1:
  return clampf(Shift.arrival_base(day)*flow,6,20)
 # Keep event differences visible after all traffic upgrades reach the interval floor.
 var event_factor=1.2 if data.shift.event_id=="rain" else (0.85 if data.shift.event_id=="festival" else 1.0)
 var base=clampf(clampf(10.8-.10*(day-6),8,10.8)*flow/event_factor,6,20)
 base=minf(20.0,base*event_factor)
 if in_rush(day,elapsed):return base*(.86-.07*market_step(day))
 var start=Shift.rush_start(day)
 if elapsed>=start+60 and elapsed<start+100:return minf(20.0,base*1.45)
 return base

static func base_price(data: Dictionary,recipe: String,critic: bool) -> int:
 var base={"espresso":50,"cappuccino":80,"latte":90}[recipe]
 if not data.has("economy"):return base
 var factor=LEAGUE_PRICE[int(data.economy.league)]
 if data.shift.event_id=="festival" or (data.shift.event_id=="milk" and recipe!="espresso"):factor*=1.1
 if critic:factor*=1.5
 var amount=base*factor*passive_factor(data,"espresso" if recipe=="espresso" else "milk_income",0.05)
 if data.shift.get("market_rules",0)==1:amount*=(100+sale_percent(int(data.shift.day_number)))/100.0
 return floori(amount)
static func equipment_price(data: Dictionary,level: int) -> int:
 var base: int=EQUIPMENT_PRICES[level]
 var discount=1.0-0.05*int(data.economy.claimed["guest-01"])
 return ceili(base*discount*(100+5*market_step(int(data.shift.day_number)))/100.0)
static func maximum_receipt(data: Dictionary) -> int:
 var base=base_price(data,"latte",data.get("shift",{}).get("event_id")=="critic")
 return base+tip_amount(data,base,100)
static func valid(e,data: Dictionary) -> bool:
 if not e is Dictionary or e.size()!=12+int(e.has("passives")) or not data.has("shift") or not data.has("upgrades") or data.has("legacy") or data.has("career"):return false
 if not data.shift is Dictionary or not data.shift.get("phase") in ["PREPARING","RUNNING","CLOSING","SUMMARY"] or not data.shift.get("event_id") in EVENTS:return false
 if e.get("version")!=1 or not e.get("offers") is Array or e.offers.size()!=3:return false
 if e.has("passives"):
  if not e.passives is Dictionary or e.passives.is_empty():return false
  for id in e.passives:
   if not id in PASSIVE_IDS or not Cup.whole(e.passives[id]) or e.passives[id]<1 or e.passives[id]>PASSIVE_PRICES.size():return false
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
