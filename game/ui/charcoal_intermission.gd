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
const RULE = Color("514338a6")
const TAB_WIDTHS = [322.0, 452.0, 338.0]
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
 view.draw_texture_rect(PAPER,Rect2(75,65,1470,830),false)
 var heading = "ПОДГОТОВКА К СМЕНЕ"
 var heading_at = Vector2(155,126)
 var day_at = heading_at + Vector2(view.sheet_font.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x+14,0)
 sheet_text(view,heading_at,heading,24)
 sheet_text(view,day_at,day,30,COPPER)
 if view.shop_tab==0:
  var forecast_at = day_at + Vector2(view.sheet_font.get_string_size(day,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x+35,0)
  sheet_text(view,forecast_at,FORECAST[state.shift.event_id],23)
 rule(view,142,1479,143)
 rule(view,138,1494,255)
 for i in range(3):
  var rect: Rect2 = view.tab_rect(i)
  var size=Vector2(TAB_WIDTHS[i],65)
  view.draw_texture_rect(TABS[i],Rect2(rect.get_center()-size/2-Vector2(0,7),size),false)
  if view.shop_tab==i:draw_underline(view,rect.get_center().x,TAB_WIDTHS[i],view.stroke_progress)
 match int(view.shop_tab):
  0: draw_rituals(view,state)
  1: draw_equipment(view,state)
  2: draw_passives(view)
 if view.shop_message!="":sheet_text(view,Vector2(143,786),view.shop_message,20,COPPER)
 sheet_text(view,Vector2(142,830),"Одно усиление на смену" if view.shop_tab==0 else "Постоянные улучшения",26)
 paper_button(view,view.START_BUTTON,"Начать смену",true,false,day)

static func draw_underline(view,x: float,width: float,progress: float) -> void:
 if progress<=0:return
 for row in range(2):
  var left=x-width*.52+row*12
  var span=width*(1.04-row*.06)
  var points=PackedVector2Array()
  var count=ceili(16*progress)
  for i in range(count+1):
   var t=minf(float(i)/16,progress)
   points.append(Vector2(left+span*t,230+row*10-12.0*sin(t*PI)+sin(t*29+row)*1.4))
  view.draw_polyline(points,INK if row==0 else RULE,4-row,true)

static func draw_rituals(view,state: Dictionary) -> void:
 for i in range(state.economy.offers.size()):
  var id: String = state.economy.offers[i]
  var item: Dictionary = view.game.Career.PERKS[id]
  var rect: Rect2 = view.offer_rect(i)
  card(view,rect)
  view.draw_texture_rect(RITUALS[item.art],Rect2(rect.position+Vector2(12,11),Vector2(rect.size.x-24,222)),false)
  centered(view,rect,rect.position.y+277,item.name,34)
  centered(view,rect,rect.position.y+318,item.description,24)
  var price: int=view.game.Career.purchase_price(state,int(item.price))
  var picked: bool = state.economy.choice==id
  var available: bool = state.economy.choice=="" and state.money>=price
  paper_button(view,Rect2(rect.get_center().x-92,rect.end.y-86,184,61),"Выбрано" if picked else price_text(price),available or picked,not picked)

static func draw_equipment(view,state: Dictionary) -> void:
 var tiers: int = view.game.Career.EQUIPMENT_PRICES.size()
 for i in range(4):
  var id: String = view.EQUIPMENT_IDS[i]
  var level: int = state.upgrades[id]
  var rect: Rect2 = view.gear_rect(i)
  card(view,rect)
  view.draw_texture_rect(GEAR[i],Rect2(rect.position+Vector2(9,9),Vector2(rect.size.x-18,195)),false)
  centered(view,rect,rect.position.y+239,["Кофемолка","Капучинатор","Кофеварка","Реклама"][i],30)
  centered(view,rect,rect.position.y+278,str(level)+"/"+str(tiers),26)
  var width: float = (rect.size.x-54)/tiers
  for n in range(tiers):
   var step = Rect2(rect.position+Vector2(27+n*width,288),Vector2(width,17))
   view.draw_rect(step,Color("89974e") if n<level else Color("bcad97"))
   view.draw_rect(step,INK,false,1,true)
  var description = "Гости приходят чаще"
  if id!="ads":
   var station: int = ["grind","brew","milk"].find(id)
   var taps: int = view.game.Career.targets(state,"cappuccino")[station]
   if id=="milk":
    var latte: int = view.game.Career.targets(state,"latte")[station]
    description="Кап. %d → %d · Латте %d → %d" % [taps,maxi(1,taps-1),latte,maxi(1,latte-1)] if level<tiers else "Капучино %d · Латте %d" % [taps,latte]
   else:description="%d → %d тапов" % [taps,maxi(1,taps-1)] if level<tiers else "%d тапов" % taps
  centered(view,rect,rect.position.y+341,description,22)
  var price: int = view.game.Career.equipment_price(state,level) if level<tiers else 0
  paper_button(view,Rect2(rect.position+Vector2(28,362),Vector2(rect.size.x-56,55)),
   "Максимум" if level>=tiers else price_text(price),level<tiers and state.money>=price,level<tiers)
  if level<tiers and state.money<price:
   centered(view,rect,rect.position.y+439,"Не хватает "+price_text(price-int(state.money)),19)

static func passive_rect(i: int) -> Rect2:
 return Rect2(131+681*floori(i/5.0),299+85*(i%5),657,80)

static func passive_button_rect(i: int) -> Rect2:
 var rect=passive_rect(i)
 return Rect2(rect.end.x-152,rect.position.y+15,134,52)

static func passive_description(i: int,level: int) -> String:
 match i:
  3: return "+%d известности за хорошую выдачу" % level
  4: return "+%d к приросту отношений" % level
  5: return "Интервал входа −%d%%" % roundi((1.0-pow(0.97,level))*100)
  8: return "+%d с на сбор оплаты" % (2*level)
  _: return "+%d%% %s" % [level*(5 if i in [1,2] else 10),PASSIVES[i][1].to_lower()]

static func draw_passives(view) -> void:
 sheet_text(view,Vector2(147,286),"ДОХОД И РЕПУТАЦИЯ",23)
 sheet_text(view,Vector2(826,286),"ПОТОК И ОБСЛУЖИВАНИЕ",23)
 for i in range(PASSIVES.size()):
  var rect=passive_rect(i)
  var career=view.game.Career
  var level: int=career.passive_level(view.game.data,career.PASSIVE_IDS[i])
  var tiers: int=career.PASSIVE_PRICES.size()
  var progress=float(level)/tiers
  var price: int=career.purchase_price(view.game.data,int(career.PASSIVE_PRICES[level])) if level<tiers else 0
  card(view,rect)
  var fill=progress
  if view.purchase_animation.get("row",-1)==i:
   fill=(float(level-1)+view.purchase_progress())/tiers
  if fill>0:
   view.draw_rect(Rect2(rect.position+Vector2.ONE,Vector2((rect.size.x-2)*fill,rect.size.y-2)),Color("78894b80"))
  view.draw_texture_rect(ICONS[i],Rect2(rect.position+Vector2(18,3),Vector2(56,53)),false)
  sheet_text(view,rect.position+Vector2(20,72),str(roundi(progress*100))+"%",19)
  sheet_text(view,rect.position+Vector2(107,33),PASSIVES[i][0],28)
  var effect=passive_description(i,level)
  var effect_at=rect.position+Vector2(107,62)
  var effect_size=20
  var effect_width=passive_button_rect(i).position.x-effect_at.x-10
  while effect_size>14 and view.sheet_font.get_string_size(effect,HORIZONTAL_ALIGNMENT_LEFT,-1,effect_size).x>effect_width:
   effect_size-=1
  sheet_text(view,effect_at,effect,effect_size)
  paper_button(view,passive_button_rect(i),"Макс." if level>=tiers else price_text(price),level<tiers and view.game.data.money>=price,level<tiers)

static func price_text(amount: int) -> String:
 if amount<1000:return str(amount)
 return str(amount/1000)+" %03d"%(amount%1000)

static func rule(view,left: float,right: float,y: float) -> void:
 view.draw_polyline(PackedVector2Array([Vector2(left,y),Vector2(left+337,y-1),Vector2(right-255,y+1),Vector2(right,y)]),RULE,2,true)

static func border(view,rect: Rect2) -> void:
 var a=rect.position
 var b=rect.end
 var points=PackedVector2Array([a+Vector2(0,4),a+Vector2(4,0),Vector2(b.x-4,a.y+1),Vector2(b.x,a.y+5),b-Vector2(0,4),b-Vector2(4,0),Vector2(a.x+4,b.y-1),Vector2(a.x,b.y-5),a+Vector2(0,4)])
 view.draw_polyline(points,INK,2,true)
 view.draw_rect(rect.grow(2),Color("59493a39"),false,1,true)

static func card(view,rect: Rect2) -> void:
 view.draw_rect(rect,Color("846a4324"))
 border(view,rect)

static func sheet_text(view,at: Vector2,label: String,size: int,color=INK) -> void:
 view.draw_string(view.sheet_font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func centered(view,rect: Rect2,y: float,label: String,size: int) -> void:
 var width: float = view.sheet_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 while width>rect.size.x-12 and size>14:
  size-=1
  width=view.sheet_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 sheet_text(view,Vector2(rect.get_center().x-width/2,y),label,size)

static func paper_button(view,rect: Rect2,label: String,active: bool,coin=false,day="") -> void:
 view.draw_rect(rect,Color("d4a16b") if active else Color("b5aa9d"))
 for i in range(ceili(rect.size.x/12.0)-2):
  var x=rect.position.x+11+i*12
  var y=rect.position.y+7+fmod(i*13.0,rect.size.y-24)
  view.draw_line(Vector2(x,y+10),Vector2(x+8,y),Color("674d3929"),1,true)
 view.draw_rect(rect.grow(-4),Color("70503855"),false,1,true)
 border(view,rect)
 var y=rect.get_center().y+8
 if not day.is_empty():
  sheet_text(view,rect.position+Vector2(20,rect.size.y*.5+9),label,28)
  sheet_text(view,Vector2(rect.end.x-89,y),day,29,COPPER)
  sheet_text(view,Vector2(rect.end.x-33,y),"→",28)
  return
 if coin:
  var width: float = view.sheet_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
  var center=rect.get_center()-Vector2((width+12)/2,0)
  view.draw_circle(center,11,Color("876d4c"))
  view.draw_circle(center,11,INK,false,2,true)
  view.draw_circle(center,7,Color("e1c9a5"),false,1,true)
  rect.position.x+=15
 centered(view,rect,y,label,28)
