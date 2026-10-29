extends Control
const Session = preload("res://orders/session.gd")
const Repository=preload("res://persistence/repository.gd")
var career_enabled=true
var save_directory="user://saves"
var repository
const Gate = preload("res://ui/pointer_gate.gd")
var game = Session.new()
var cup_position=Vector2(770,740)
var dragging=false
var next_in=0.0
var last_purchase=-1000
var upgrade_ids=["grind","brew","milk","tuning","grace","ads"]
var upgrade_names=["Жернова","Кофемашина","Молоко","Точная настройка","Защита","Реклама"]
const CUP_HOME=Vector2(770,740)
const GUEST_RECT=Rect2(1300,180,260,480)
const COIN_RECT=Rect2(1360,550,150,100)
var pointer = Gate.new()
var paused=false
var station_rects=[Rect2(60,370,360,260),Rect2(490,370,360,260),Rect2(920,370,360,260)]
var station_names=["Помол","Варка","Молоко"]
var message="Начни с кофемолки. Переход к следующему прибору — вручную."
var font=ThemeDB.fallback_font
func _ready() -> void:
 repository=Repository.new(save_directory,career_enabled)
 game=repository.session
 if not repository.ready: message="Сохранение повреждено. Нажми «Сброс профиля» для явного сброса."
 queue_redraw()
func act(method: String,args: Array=[]) -> bool:
 var success=repository.apply(method,args)
 game=repository.session
 if repository.error!="": message="Не удалось сохранить. Действие отменено: "+repository.error
 return success
func _process(delta: float) -> void:
 if paused: return
 repository.advance(delta)
 game=repository.session
 if not repository.ready: return
 if not dragging: cup_position=cup_position.lerp(CUP_HOME,minf(1,delta*14))
 if game.data.order.state in ["COLLECTED","LEFT","UNPAID"]:
  if game.data.order.get("arrival_remaining",0)<=0:
   act("next_order")
   next_in=0
   cup_position=CUP_HOME
 queue_redraw()
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
  paused=true
  if repository: repository.checkpoint()
  if pointer: pointer.cancel()
  queue_redraw()
func _input(event: InputEvent) -> void:
 var action=pointer.route(event)
 if action.is_empty(): return
 var point=action.position
 if not paused:
  repository.advance(0)
  game=repository.session
 if action.action=="press":
  if Rect2(1380,30,170,65).has_point(point):
   paused=not paused
   pointer.cancel()
   dragging=false
  elif Rect2(1150,30,190,65).has_point(point):
   repository.restart()
   game=repository.session
   message="Новая тестовая попытка" if repository.ready else "Не удалось сохранить"
  elif Rect2(900,30,180,65).has_point(point):
   if repository.training: repository.end_training()
   else: repository.begin_training()
   game=repository.session
  elif not paused and repository.ready and game.shift!=null and game.shift.data.mode=="SHOP" and Rect2(430,350,740,145).has_point(point):
   if Time.get_ticks_msec()-last_purchase>=350:
    for i in range(6):
     if Rect2(430+(i%3)*250,350+floori(i/3.0)*75,230,65).has_point(point):
      last_purchase=Time.get_ticks_msec()
      act("purchase",[upgrade_ids[i],int(game.data.upgrades[upgrade_ids[i]])])
  elif not paused and repository.ready and game.shift!=null and game.shift.data.mode=="SHOP" and Rect2(430,510,740,60).has_point(point):
   for i in range(3):
    if Rect2(430+i*250,510,230,60).has_point(point): act("choose_perk",[game.shift.data.offers[i]])
  elif not paused and repository.ready and game.shift!=null and Rect2(560,600,440,70).has_point(point):
   if game.shift.data.mode=="SHOP":
    if not act("start_shift"): message="Сначала выбери временное усиление"
   elif game.shift.data.mode=="SUMMARY": act("collect_reward")
  elif not paused and repository.ready:
   if game.data.order.state=="PAYMENT" and COIN_RECT.has_point(point):
    act("collect",[game.data.order.payment.id])
   elif game.brew.locked and game.data.order.state=="BREWING" and GUEST_RECT.has_point(point):
    act("deliver",[game.data.order.id,game.data.order.customer_id])
   elif game.data.order.state=="BREWING" and game.brew.ready() and Rect2(CUP_HOME-Vector2(60,90),Vector2(120,160)).has_point(point):
    if game.brew.locked or act("take_cup"):
     dragging=true
     cup_position=point
   else:
    for index in range(station_rects.size()):
     if station_rects[index].has_point(point):
      if act("tap",[index]): message="Готово — переключи прибор" if game.brew.complete(index) else "Продолжай"
 elif not paused and action.action=="move" and dragging:
  cup_position=point
 elif action.action=="release" and dragging:
  dragging=false
  if not paused and GUEST_RECT.has_point(point):
   act("deliver",[game.data.order.id,game.data.order.customer_id])
  else: message="Мимо. Стакан возвращается на стойку."
 queue_redraw()
func text_at(point: Vector2, value: String, size=26, color=Color("eddfc8")) -> void:
 draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func _draw() -> void:
 text_at(Vector2(60,65),"ПУТЬ БАРИСТЫ",36)
 text_at(Vector2(60,110),"Технический прототип; оформление не утверждено",24,Color("d4b376"))
 draw_style_box(panel(Color("26313b")),Rect2(1380,30,170,65))
 draw_style_box(panel(Color("26313b")),Rect2(900,30,180,65))
 text_at(Vector2(915,73),"Выйти" if repository.training else "Тренировка",22)
 draw_style_box(panel(Color("26313b")),Rect2(1150,30,190,65))
 text_at(Vector2(1165,73),"Заново" if repository.training else "Сброс профиля",22)
 text_at(Vector2(1400,73),"Продолжить" if paused else "Пауза",22)
 text_at(Vector2(60,220),{"espresso":"Эспрессо","cappuccino":"Капучино","latte":"Латте"}[game.data.order.recipe],38)
 text_at(Vector2(700,65),str(game.data.money)+" монет",30)
 text_at(Vector2(60,280),message,24)
 if repository.error!="": text_at(Vector2(60,840),"Ошибка сохранения: "+repository.error,26,Color("ee9a86"))
 for index in range(game.brew.targets.size()):
  draw_style_box(panel(Color("25322f")),station_rects[index])
  text_at(station_rects[index].position+Vector2(28,65),station_names[index],32)
  var progress=clampf(float(game.brew.taps[index])/game.brew.targets[index],0,1)
  var color=Color("e49a83") if game.brew.qualities()[index]<1 else Color("80c8a5")
  draw_style_box(panel(Color("111920")),Rect2(station_rects[index].position+Vector2(28,130),Vector2(300,16)))
  if progress>0: draw_style_box(panel(color),Rect2(station_rects[index].position+Vector2(28,130),Vector2(300*progress,16)))
  text_at(station_rects[index].position+Vector2(28,200),"Перетап · вкус испорчен" if game.brew.qualities()[index]<1 else "Готово" if game.brew.complete(index) else "Тапай по прибору",22)
 text_at(Vector2(1310,170),game.data.order.customer_id,28)
 draw_circle(Vector2(1420,290),70,Color("bd9877"))
 draw_circle(Vector2(1398,280),5,Color("29313a"))
 draw_circle(Vector2(1442,280),5,Color("29313a"))
 var profile=game.data.profiles[game.data.order.customer_id]
 draw_line(Vector2(1390,320),Vector2(1450,320),Color("29313a"),4)
 if profile.mood=="happy": draw_arc(Vector2(1420,304),30,0,PI,16,Color("29313a"),4)
 draw_style_box(panel(Color("506774")),Rect2(1330,380,180,160))
 text_at(Vector2(1305,700),profile.last_reaction,24)
 if game.data.order.state=="PAYMENT":
  draw_style_box(panel(Color("a27d39")),COIN_RECT)
  text_at(COIN_RECT.position+Vector2(16,40),str(game.data.order.payment.amount)+" монет",22)
  text_at(Vector2(1290,735),"Чаевые: "+str(game.data.order.payment.get("tip",0)),22)
 if game.data.order.state=="BREWING" and game.brew.ready():
  draw_style_box(panel(Color("e5d2ad")),Rect2(cup_position-Vector2(35,55),Vector2(70,100)))
  text_at(cup_position+Vector2(-95,85),"Перетащи гостю",22)
 if game.shift!=null:
  text_at(Vector2(60,170),"Смена: "+str(int(game.shift.data.remaining))+" сек. · "+game.shift.data.day_key,24)
  var mode=game.shift.data.mode
  if mode in ["SHOP","SUMMARY","FINISHED"]:
   draw_style_box(panel(Color("1b252f")),Rect2(380,200,840,530))
   text_at(Vector2(450,270),"Магазин нового дня" if mode=="SHOP" else "Смена завершена",36)
   text_at(Vector2(450,330),"Баланс: "+str(game.data.money)+" монет",26)
   if mode=="SHOP":
    for i in range(6):
     var rect=Rect2(430+(i%3)*250,350+floori(i/3.0)*75,230,65)
     draw_style_box(panel(Color("32413e")),rect)
     var level=int(game.data.upgrades[upgrade_ids[i]])
     text_at(rect.position+Vector2(12,25),upgrade_names[i]+" · "+str(level),20)
     text_at(rect.position+Vector2(12,55),"Максимум" if level>=Session.UPGRADES[upgrade_ids[i]] else str(Session.UPGRADE_PRICES[level])+" монет",20)
   if mode=="SHOP":
    var perk_names={"grind":"Помол −2","brew":"Варка −2","milk":"Молоко −2","grace":"Защита +1","patience":"Терпение +25%"}
    for i in range(3):
     var rect=Rect2(430+i*250,510,230,60)
     draw_style_box(panel(Color("56755d") if game.shift.data.perk==game.shift.data.offers[i] else Color("354350")),rect)
     text_at(rect.position+Vector2(10,36),perk_names[game.shift.data.offers[i]],21)
    var event_names={"calm":"Спокойное утро","rush":"Час пик","milk":"Любители молочного","connoisseur":"Кофейные ценители"}
    text_at(Vector2(450,700),"Условие: "+event_names[game.shift.data.event],22)
   var button="Начать смену" if mode=="SHOP" else "Забрать итог" if mode=="SUMMARY" else "Следующая смена после 08:00"
   draw_style_box(panel(Color("3f6455")),Rect2(560,600,440,70))
   text_at(Vector2(600,645),button,24)
 if paused:
  draw_rect(Rect2(0,320,1600,580),Color(0.03,0.04,0.06,0.82))
  text_at(Vector2(650,740),"ПАУЗА",48)
func panel(color: Color) -> StyleBoxFlat:
 var style=StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(24)
 return style
