extends RefCounted
## The art is sampled from VISUAL-003/v3. Live prices and balances come from the session.

const ART = "res://content/art/charcoal/"
const PAPER = preload(ART+"paper.webp")
const TABS = [preload(ART+"tab-0.webp"), preload(ART+"tab-1.webp"), preload(ART+"tab-2.webp")]
const RITUALS = {
 "warmth": preload(ART+"ritual-0.webp"), "change": preload(ART+"ritual-1.webp"),
 "aroma": preload(ART+"ritual-2.webp"), "focus": preload(ART+"gear-0.webp")
}
const GEAR = [preload(ART+"gear-0.webp"), preload(ART+"gear-1.webp"), preload(ART+"gear-2.webp"), preload(ART+"gear-3.webp")]
const ICONS = [
 preload(ART+"passive-0.webp"), preload(ART+"passive-1.webp"), preload(ART+"passive-2.webp"),
 preload(ART+"passive-3.webp"), preload(ART+"passive-4.webp"), preload(ART+"passive-5.webp"),
 preload(ART+"passive-6.webp"), preload(ART+"passive-7.webp"), preload(ART+"passive-8.webp"),
 preload(ART+"passive-9.webp")
]
const INK = Color("31271f")
const COPPER = Color("9a4b27")
const FORECAST = {
 "calm":"Обычное утро · привычный поток гостей", "rain":"Дождливое утро · гости приходят реже",
 "regulars":"Утро постоянников · чаще заказывают любимый кофе",
 "festival":"Фестиваль · гости приходят чаще, цены выше",
 "milk":"Молочный день · больше заказов на молочный кофе",
 "critic":"Ожидается критик · первый заказ принесёт больше монет"
}
const PASSIVES = [
 ["Щедрые гости","К сумме чаевых"], ["Чёрный кофе","К выручке за эспрессо"],
 ["Молочное меню","К выручке за капучино и латте"], ["Добрая слава","К получаемой известности"],
 ["Тёплый приём","К приросту отношений"], ["Оживлённая улица","К частоте прихода гостей"],
 ["Без спешки","К времени ожидания"], ["Тепло в чашке","К времени до остывания"],
 ["Монеты на блюдце","К времени на сбор оплаты"], ["Ясный заказ","К времени показа заказа"]
]

static func draw_sheet(view) -> void:
 var state: Dictionary = view.game.data
 var day: String = str(state.shift.day_number)
 view.draw_rect(Rect2(0,48,1600,852),Color("121014a0"))
 var paper = Rect2(82,72,1460,804)
 view.draw_texture_rect(PAPER,paper,false)
 view.text_at(Vector2(154,124),"ПОДГОТОВКА К СМЕНЕ",26,INK)
 view.text_at(Vector2(488,124),day,30,COPPER)
 if view.shop_tab==0:
  view.text_at(Vector2(591,124),FORECAST[state.shift.event_id],25,INK)
 view.draw_line(Vector2(133,141),Vector2(1488,141),Color("6b594c"),2,true)
 view.draw_line(Vector2(133,254),Vector2(1488,254),Color("6b594c"),2,true)
 for i in range(3):
  var rect: Rect2 = view.tab_rect(i)
  var size: Vector2 = TABS[i].get_size()*.90
  view.draw_texture_rect(TABS[i],Rect2(rect.get_center()-size/2-Vector2(0,10),size),false)
  if view.shop_tab==i:
   var y: float = rect.end.y-20
   var x: float = rect.get_center().x
   var stroke: float=view.stroke_progress
   view.draw_line(Vector2(x-153,y+3),Vector2(x-153+307*stroke,y+3-4*stroke),INK,5,true)
   view.draw_line(Vector2(x-130,y+8),Vector2(x-130+243*stroke,y+8-6*stroke),INK,2,true)
 match int(view.shop_tab):
  0: draw_rituals(view,state)
  1: draw_equipment(view,state)
  2: draw_passives(view)
 if view.shop_message!="":
  view.text_at(Vector2(148,778),view.shop_message,21,COPPER)
 view.text_at(Vector2(146,830),["Одно усиление на смену","Постоянные улучшения","Постоянные бонусы"][view.shop_tab],24,INK)
 paper_button(view,view.EXTRA_BUTTON,"Карьера",false)
 paper_button(view,view.START_BUTTON,"Начать смену  "+day+"  →",true)

static func draw_rituals(view,state: Dictionary) -> void:
 for i in range(state.economy.offers.size()):
  var id: String = state.economy.offers[i]
  var item: Dictionary = view.game.Career.PERKS[id]
  var rect: Rect2 = view.offer_rect(i)
  card(view,rect)
  view.draw_texture_rect(RITUALS[item.art],Rect2(rect.position+Vector2(12,12),Vector2(rect.size.x-24,218)),false)
  centered(view,rect,rect.position.y+272,item.name,29)
  centered(view,rect,rect.position.y+313,item.description,22)
  var picked: bool = state.economy.choice==id
  var available: bool = state.economy.choice=="" and state.money>=item.price
  paper_button(view,Rect2(rect.get_center().x-95,rect.end.y-85,190,57),"✓" if picked else str(item.price),available,not picked)

static func draw_equipment(view,state: Dictionary) -> void:
 var tiers: int = view.game.Career.EQUIPMENT_PRICES.size()
 for i in range(4):
  var id: String = view.EQUIPMENT_IDS[i]
  var level: int = state.upgrades[id]
  var rect: Rect2 = view.gear_rect(i)
  card(view,rect)
  view.draw_texture_rect(GEAR[i],Rect2(rect.position+Vector2(12,12),Vector2(rect.size.x-24,202)),false)
  centered(view,rect,rect.position.y+248,["Кофемолка","Капучинатор","Кофеварка","Реклама"][i],29)
  centered(view,rect,rect.position.y+284,str(level)+"/"+str(tiers),23)
  var width: float = (rect.size.x-54)/10
  for n in range(10):
   var step = Rect2(rect.position+Vector2(27+n*width,295),Vector2(width-2,17))
   var fill = Color("839757") if n<level else (Color("bfb099") if n<tiers else Color("a99c89"))
   view.draw_rect(step,fill)
   view.draw_rect(step,INK,false,1,true)
  centered(view,rect,rect.position.y+347,"Гости приходят чаще" if id=="ads" else "На 1 тап меньше за уровень",20)
  var price: int = view.game.Career.equipment_price(state,level) if level<tiers else 0
  paper_button(view,Rect2(rect.position+Vector2(28,368),Vector2(rect.size.x-56,56)),
   "Максимум" if level>=tiers else str(price),level<tiers and state.money>=price,level<tiers)

static func passive_rect(i: int) -> Rect2:
 return Rect2(132+681*floori(i/5.0),296+85*(i%5),651,76)

static func passive_button_rect(i: int) -> Rect2:
 var rect=passive_rect(i)
 return Rect2(rect.end.x-143,rect.position.y+14,131,47)

static func passive_description(i: int,level: int) -> String:
 match i:
  3: return "+%d известности за хорошую выдачу" % level
  4: return "+%d к положительному приросту отношений" % level
  5: return "Интервал входа −%d%%" % roundi((1.0-pow(0.97,level))*100)
  8: return "+%d с на сбор оплаты" % (2*level)
  _: return "+%d%% %s" % [level*(5 if i in [1,2] else 10),PASSIVES[i][1].to_lower()]

static func draw_passives(view) -> void:
 view.text_at(Vector2(147,281),"ДОХОД И РЕПУТАЦИЯ",22,INK)
 view.text_at(Vector2(833,281),"ПОТОК И ОБСЛУЖИВАНИЕ",22,INK)
 for i in range(PASSIVES.size()):
  var rect=passive_rect(i)
  var career=view.game.Career
  var level: int=career.passive_level(view.game.data,career.PASSIVE_IDS[i])
  var tiers: int=career.PASSIVE_PRICES.size()
  var progress=float(level)/tiers
  var price: int=career.PASSIVE_PRICES[level] if level<tiers else 0
  card(view,rect)
  var fill=progress
  if view.purchase_animation.get("row",-1)==i:
   fill=(float(level-1)+view.purchase_progress())/tiers
  if fill>0:
   view.draw_rect(Rect2(rect.position+Vector2.ONE,Vector2((rect.size.x-2)*fill,rect.size.y-2)),Color("78894b80"))
  view.draw_texture_rect(ICONS[i],Rect2(rect.position+Vector2(18,5),Vector2(56,50)),false)
  view.text_at(rect.position+Vector2(21,70),str(roundi(progress*100))+"%",16,INK)
  view.text_at(rect.position+Vector2(91,29),PASSIVES[i][0],24,INK)
  view.text_at(rect.position+Vector2(91,58),passive_description(i,level),17,INK)
  paper_button(view,passive_button_rect(i),"Макс." if level>=tiers else str(price),level<tiers and view.game.data.money>=price,level<tiers)

static func card(view,rect: Rect2) -> void:
 view.draw_rect(rect,Color("846a4324"))
 view.draw_rect(rect,INK,false,2,true)

static func centered(view,rect: Rect2,y: float,label: String,size: int) -> void:
 var width: float = view.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 while width>rect.size.x-12 and size>14:
  size-=1
  width=view.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 view.text_at(Vector2(rect.get_center().x-width/2,y),label,size,INK)

static func paper_button(view,rect: Rect2,label: String,active: bool,coin=false) -> void:
 view.draw_rect(rect,Color("cf9e63") if active else Color("b7ad9d"))
 view.draw_rect(rect,INK,false,2,true)
 if coin:
  view.draw_circle(Vector2(rect.get_center().x-49,rect.get_center().y),9,INK,false,2,true)
  view.draw_circle(Vector2(rect.get_center().x-49,rect.get_center().y),5,INK,false,1,true)
  rect.position.x+=15
 centered(view,rect,rect.get_center().y+9,label,25)
