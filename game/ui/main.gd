extends Control
const Session = preload("res://orders/session.gd")
const Repository=preload("res://persistence/repository.gd")
var career_enabled=true
var save_directory="user://saves"
var repository
const Gate = preload("res://ui/pointer_gate.gd")
var game = Session.new()
var cup_position=Vector2(650,760)
var dragging=false
var cup_grab_offset=Vector2.ZERO
var next_in=0.0
var shop_message=""
var last_purchase=-1000
var upgrade_ids=["grind","brew","milk","tuning","grace","ads"]
var upgrade_names=["Жернова","Кофемашина","Молоко","Точная настройка","Защита","Реклама"]
const CUP_HOME=Vector2(650,760)
const GUEST_RECT=Rect2(970,210,330,460)
const COIN_RECT=Rect2(890,555,130,110)
var pointer = Gate.new()
var intro_elapsed=0.0
var reset_pending=false
var paused=false
var screen=""
var return_screen=""
var lesson_completed=false
var station_rects=[Rect2(30,495,299,355),Rect2(378,388,329,292),Rect2(758,302,182,218)]
var station_names=["Помол","Варка","Молоко"]
var message="Начни с кофемолки. Переход к следующему прибору — вручную."
var font=ThemeDB.fallback_font
const Actor=preload("res://ui/cafe_actor.gd")
var barista=Actor.new()
var guest=Actor.new()
var shown_order=-1
var visual_clock=0.0
var bar_progress=[0.0,0.0,0.0]
var outlines=[preload("res://content/art/cafe/outline0.svg"),preload("res://content/art/cafe/outline1.svg"),preload("res://content/art/cafe/outline2.svg")]
var cup_textures={"espresso":preload("res://content/art/cafe/cup-espresso.svg"),"cappuccino":preload("res://content/art/cafe/cup-cappuccino.svg"),"latte":preload("res://content/art/cafe/cup-latte.svg")}
var room=preload("res://content/art/cafe/room.png")
const RECIPE_NAMES={"espresso":"Эспрессо","cappuccino":"Капучино","latte":"Латте"}
const BAR_POSITIONS=[Vector2(64,486),Vector2(432,360),Vector2(768,261)]
const MENU_BUTTON=Rect2(1430,22,130,76)
const MENU_RESUME=Rect2(560,385,480,80)
const MENU_SOUND=Rect2(560,485,480,80)
const MENU_PROGRESS=Rect2(560,585,480,80)
const MENU_REPORT=Rect2(560,685,480,80)
const BACK_BUTTON=Rect2(30,22,320,76)
var audio
# Temporary diagnostic mitigation: each Android launch starts silent.
var audio_safe_start=OS.get_name()=="Android"
var report_copied=false
func _exit_tree() -> void:
 barista.free()
 guest.free()
func sync_guest(immediate=false) -> void:
 var order=game.data.order
 if int(order.id)!=shown_order:
  shown_order=int(order.id)
  guest.enter("beard" if int(order.customer_id.right(2))%2==1 else "hawaii",immediate)
 guest.set_emotion(game.data.profiles[order.customer_id].mood)
 guest.held_cup=order.state in ["PAYMENT","COLLECTED","UNPAID"]
 guest.cup_recipe=order.recipe
 if order.state in ["COLLECTED","LEFT","UNPAID","CLOSED","DORMANT"]: guest.depart()
func _ready() -> void:
 repository=Repository.new(save_directory,career_enabled)
 game=repository.session
 barista.enter("barista",true)
 sync_guest(true)
 if game.data.order.state=="DORMANT": guest.phase="gone"
 screen="intro" if career_enabled else ""
 if not repository.ready: message="Не удалось прочитать сохранение. Прогресс не перезаписан."
 audio=load("res://ui/cafe_audio.gd").new()
 audio.begin_diagnostics(save_directory+"/audio-diagnostic.txt")
 add_child(audio)
 update_audio()
 queue_redraw()
func update_audio() -> void:
 if audio:
  var prefs=repository.preferences().duplicate()
  if audio_safe_start: prefs.muted=true
  audio.set_active(not paused and screen in ["","lesson"] and repository.ready,prefs)
func act(method: String,args: Array=[]) -> bool:
 var success=repository.apply(method,args)
 game=repository.session
 if repository.error!="": message="Не удалось сохранить. Действие отменено: "+repository.error
 if success and audio:
  if method=="tap": audio.effect(["grind","brew","steam"][args[0]])
  elif method=="collect": audio.effect("coins")
 return success
func finish_intro() -> void:
 intro_elapsed=3.0
 screen=""
 paused=false
 update_audio()
 queue_redraw()
func open_menu() -> void:
 screen="menu"
 paused=true
 dragging=false
 cup_position=CUP_HOME
 pointer.cancel()
 if repository: repository.checkpoint()
 update_audio()
 queue_redraw()
func resume_game() -> void:
 screen="lesson" if repository.training and not lesson_completed else ""
 paused=false
 pointer.cancel()
 update_audio()
 queue_redraw()
func _process(delta: float) -> void:
 if paused: return
 if screen=="intro":
  intro_elapsed=minf(3,intro_elapsed+delta)
  if intro_elapsed>=3: finish_intro()
  queue_redraw()
  return
 if paused or screen in ["menu","progress"]: return
 repository.advance(delta)
 game=repository.session
 if not repository.ready: return
 visual_clock+=delta
 barista.step(delta)
 sync_guest()
 guest.step(delta)
 for i in range(game.brew.targets.size()):
  var target=clampf(float(game.brew.taps[i])/game.brew.targets[i],0,1)
  bar_progress[i]=move_toward(bar_progress[i],target,delta*3.5)
 if not dragging: cup_position=cup_position.lerp(CUP_HOME,minf(1,delta*14))
 if game.data.order.state in ["COLLECTED","LEFT","UNPAID"]:
  if game.data.order.get("arrival_remaining",0)<=0 and guest.phase=="gone":
   act("next_order")
   sync_guest()
   bar_progress=[0.0,0.0,0.0]
   cup_position=CUP_HOME
 queue_redraw()
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
  if repository:
   if screen=="intro":
    repository.checkpoint()
    paused=true
    update_audio()
   else: open_menu()
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN or what==NOTIFICATION_APPLICATION_RESUMED:
  if screen=="intro": paused=false
func _input(event: InputEvent) -> void:
 var action=pointer.route(event)
 if action.is_empty(): return
 var point=action.position
 if action.action=="cancel":
  dragging=false
  queue_redraw()
  return
 if screen=="intro":
  if action.action=="press" and not paused:
   finish_intro()
   pointer.cancel()
  return
 if action.action=="press":
  if screen=="menu":
   if not repository.ready:
    if MENU_RESUME.has_point(point):
     if reset_pending:
      if repository.restart():
       game=repository.session
       reset_pending=false
       shown_order=-1
       sync_guest(true)
       if game.data.order.state=="DORMANT": guest.phase="gone"
       resume_game()
     else: reset_pending=true
    elif MENU_SOUND.has_point(point): reset_pending=false
    pointer.cancel()
    queue_redraw()
    return
   if MENU_RESUME.has_point(point): resume_game()
   elif MENU_SOUND.has_point(point):
    if repository.set_preference("muted",not audio.muted): audio_safe_start=false
    update_audio()
   elif MENU_PROGRESS.has_point(point): screen="progress"
   elif MENU_REPORT.has_point(point):
    DisplayServer.clipboard_set(audio.report())
    report_copied=true
   pointer.cancel()
   queue_redraw()
   return
  if screen=="progress":
   if BACK_BUTTON.has_point(point): screen="menu"
   elif game.shift!=null and game.shift.data.mode=="SHOP":
    for i in range(6):
     if shop_card(i).has_point(point):
      var level=int(game.data.upgrades[upgrade_ids[i]])
      if act("purchase",[upgrade_ids[i],level]): shop_message=upgrade_names[i]+" · уровень "+str(level+1)
      elif repository.error!="": shop_message="Покупка не сохранена"
      elif level>=Session.UPGRADES[upgrade_ids[i]]: shop_message="Улучшение уже на максимуме"
      else: shop_message="Недостаточно монет"
   pointer.cancel()
   queue_redraw()
   return
  if paused: return
  if MENU_BUTTON.has_point(point):
   open_menu()
   return
  if game.shift!=null and game.shift.data.mode=="SHOP":
   for i in range(3):
    if Rect2(415+i*265,670,250,65).has_point(point): act("choose_perk",[game.shift.data.offers[i]])
   if Rect2(560,760,480,75).has_point(point):
    if not act("start_shift"): message="Выбери усиление для этой смены"
    else: sync_guest()
   queue_redraw()
   return
  if game.shift!=null and game.shift.data.mode=="SUMMARY":
   if Rect2(560,760,480,75).has_point(point): act("collect_reward")
   queue_redraw()
   return
  if game.shift!=null and game.shift.data.mode=="FINISHED":
   if Rect2(560,760,480,75).has_point(point):
    if repository.begin_training():
     game=repository.session
     shown_order=-1
     bar_progress=[0.0,0.0,0.0]
     sync_guest()
   return
  if repository.training and Rect2(1100,800,460,65).has_point(point):
   repository.end_training()
   game=repository.session
   shown_order=-1
   sync_guest(true)
   queue_redraw()
   return
  repository.advance(0)
  game=repository.session
  if repository.ready:
   if game.data.order.state=="PAYMENT" and COIN_RECT.has_point(point):
    if act("collect",[game.data.order.payment.id]) and screen=="lesson":
     lesson_completed=true
     repository.set_preference("tutorial_seen",true)
   elif game.data.order.state=="BREWING" and game.brew.ready() and Rect2(cup_position-Vector2(60,90),Vector2(120,160)).has_point(point):
    if game.brew.locked or act("take_cup"):
     dragging=true
     cup_grab_offset=cup_position-point
   else:
    for index in range(station_rects.size()):
     if station_rects[index].has_point(point):
      var was_complete=game.brew.complete(index)
      if act("tap",[index]):
       if not was_complete and game.brew.complete(index) and repository.preferences().vibration: Input.vibrate_handheld(20)
 elif not paused and action.action=="move" and dragging: cup_position=point+cup_grab_offset
 elif action.action=="release" and dragging:
  dragging=false
  cup_position=point+cup_grab_offset
  if not paused and GUEST_RECT.has_point(cup_position): act("deliver",[game.data.order.id,game.data.order.customer_id])
 queue_redraw()
func text_at(point: Vector2,value: String,size=26,color=Color("eddfc8")) -> void:
 draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func draw_button(rect: Rect2,label: String,active=true) -> void:
 draw_style_box(panel(Color("426951") if active else Color("2b353d")),rect)
 text_at(rect.position+Vector2(22,rect.size.y*.5+9),label,25,Color("efdec0") if active else Color("a9a7a2"))
func _draw() -> void:
 draw_cafe()
 if repository==null: return
 if screen=="intro":
  draw_intro()
  return
 draw_style_box(panel(Color("111922dc")),Rect2(22,18,1556,82))
 text_at(Vector2(48,67),"ПУТЬ БАРИСТЫ",27)
 text_at(Vector2(670,66),str(game.data.money)+" монет",29,Color("ebbc76"))
 if game.shift!=null:
  text_at(Vector2(360,60),"День · "+game.shift.data.day_key,22)
  text_at(Vector2(1070,66),"%02d:%02d" % [int(game.shift.data.remaining)/60,int(game.shift.data.remaining)%60],26)
 for i in range(3): draw_line(Vector2(1468,42+i*15),Vector2(1520,42+i*15),Color("eddfc8"),4,true)
 if screen=="progress":
  draw_progress()
 elif screen=="menu":
  draw_rect(Rect2(0,100,1600,800),Color(.025,.035,.045,.78))
  text_at(Vector2(675,310),"ПАУЗА",48)
  if repository.ready:
   draw_button(MENU_RESUME,"Продолжить")
   draw_button(MENU_SOUND,"Звук выключен" if audio.muted else "Звук включён")
   draw_button(MENU_PROGRESS,"Прогресс")
   draw_button(MENU_REPORT,"Отчёт скопирован" if report_copied else "Скопировать отчёт")
   text_at(Vector2(420,815),"Предпросмотр 0.3.2 · при запуске звук выключен",24)
  else:
   draw_button(MENU_RESUME,"Подтвердить сброс" if reset_pending else "Сбросить профиль…")
   draw_button(MENU_SOUND,"Отмена")
   text_at(Vector2(470,635),"Сброс удалит монеты, улучшения и отношения.",25,Color("ee9a86"))
 else:
  draw_play()
  draw_day_controls()
 if repository.error!="":
  draw_style_box(panel(Color("1d2028f0")),Rect2(30,840,1540,48))
  text_at(Vector2(50,871),"Не удалось сохранить: "+repository.error+". Действие не записано.",23,Color("ee9a86"))
func draw_play() -> void:
 var order=game.data.order
 if order.state in ["BREWING","PAYMENT"] and guest.phase=="idle":
  var label=guest.position+Vector2(-90,-155)*guest.scale.x
  text_at(label,"Бородач" if guest.actor_id=="beard" else "Гаваец",26)
  text_at(label+Vector2(0,30),RECIPE_NAMES[order.recipe],23,Color("ddc6a6"))
  if order.state=="PAYMENT":
   draw_style_box(panel(Color("eadbc0")),Rect2(890,440,230,60))
   text_at(Vector2(908,480),game.data.profiles[order.customer_id].last_reaction,25,Color("302628"))
 if order.state=="BREWING":
  for i in range(game.brew.targets.size()):
   var color=Color("ec9d94") if game.brew.qualities()[i]<1 else Color("ebbc76") if game.brew.complete(i) else Color("82d4b5")
   draw_texture(outlines[i],Vector2.ZERO,Color(color,0.75 if game.brew.stage==i else 0.3))
   draw_style_box(panel(Color("151c26cc")),Rect2(BAR_POSITIONS[i],Vector2(176,10)))
   if bar_progress[i]>0: draw_style_box(panel(color),Rect2(BAR_POSITIONS[i],Vector2(176*bar_progress[i],10)))
 if order.state=="PAYMENT":
  for i in range(3):
   var center=COIN_RECT.get_center()+Vector2(i*14-14,-i*9+sin(visual_clock*3)*3)
   draw_circle(center,23,Color("dba74a"))
   draw_arc(center,20,0,TAU,32,Color("ffe1a2"),2)
   text_at(center+Vector2(-7,8),"₽",23,Color("80531f"))
  text_at(COIN_RECT.position+Vector2(-15,125),str(order.payment.amount)+" монет",22,Color("f2cd87"))
 if order.state=="BREWING" and game.brew.ready():
  if barista.reaching: draw_arm(cup_position)
  draw_cup(cup_position)
  if not barista.reaching: text_at(CUP_HOME+Vector2(-68,100),RECIPE_NAMES[order.recipe],22)
 if screen=="lesson": text_at(Vector2(420,160),lesson_hint(),24)
func draw_day_controls() -> void:
 if repository.training:
  draw_button(Rect2(1100,800,460,65),"Завершить тренировку")
  return
 if game.shift==null: return
 var mode=game.shift.data.mode
 if mode=="SHOP":
  draw_style_box(panel(Color("142027ed")),Rect2(390,590,820,260))
  text_at(Vector2(420,635),"Перед открытием выбери усиление дня",27)
  var names={"grind":"Помол −2","brew":"Варка −2","milk":"Молоко −2","grace":"Защита +1","patience":"Терпение +25%"}
  for i in range(3):
   var id=game.shift.data.offers[i]
   draw_button(Rect2(415+i*265,670,250,65),names[id],game.shift.data.perk=="" or game.shift.data.perk==id)
  draw_button(Rect2(560,760,480,75),"Открыть смену",game.shift.data.perk!="")
 elif mode in ["SUMMARY","FINISHED"]:
  draw_style_box(panel(Color("142027ed")),Rect2(390,640,820,210))
  text_at(Vector2(430,690),"Смена завершена · выдано "+str(game.data.stats.delivered),28)
  text_at(Vector2(430,733),"Награда: 200 монет" if game.shift.data.success else "Заработанные монеты сохранены",24,Color("ebbc76"))
  if mode=="SUMMARY": draw_button(Rect2(560,760,480,75),"Забрать итог")
  else: draw_button(Rect2(560,760,480,75),"Тренироваться до новой смены")
func shop_card(index: int) -> Rect2:
 return Rect2(355+(index%3)*370,600+floori(index/3.0)*115,350,102)
func draw_progress() -> void:
 draw_button(BACK_BUTTON,"‹ Назад в меню")
 text_at(Vector2(1070,145),"ПРОГРЕСС",32)
 if shop_message!="":
  draw_style_box(panel(Color("142027ed")),Rect2(355,530,1090,52))
  text_at(Vector2(375,565),shop_message,24)
 var effects=["−1 тап за уровень","−1 тап за уровень","−1 тап за уровень","Медленнее порча","+1 безопасный перетап","Гости приходят чаще"]
 for i in range(6):
  var rect=shop_card(i)
  var level=int(game.data.upgrades[upgrade_ids[i]])
  draw_style_box(panel(Color("1b2b30f0")),rect)
  text_at(rect.position+Vector2(16,28),upgrade_names[i]+" · "+str(level),24)
  text_at(rect.position+Vector2(16,57),effects[i],20,Color("bcb9aa"))
  text_at(rect.position+Vector2(16,86),"Максимум" if level>=Session.UPGRADES[upgrade_ids[i]] else str(Session.UPGRADE_PRICES[level])+" монет",22,Color("ebbc76"))
 text_at(Vector2(355,875),"Улучшения доступны перед открытием смены",22)
func draw_intro() -> void:
 var progress=clampf(intro_elapsed/3.0,0,1)
 draw_rect(Rect2(0,0,1600,900),Color(.005,.01,.02,1-smoothstep(.86,1,progress)))
 if progress<.86:
  var opening=smoothstep(0,.24,progress)
  draw_style_box(panel(Color("151b23")),Rect2(1140,160,240,480))
  draw_colored_polygon(PackedVector2Array([Vector2(1150,175),Vector2(1150+205*opening,190),Vector2(1150+205*opening,620),Vector2(1150,630)]),Color("a58c67"))
  var travel=smoothstep(.18,.8,progress)
  var at=Vector2(1230,500).lerp(Vector2(860,550),travel)
  var original_position=barista.position
  var original_scale=barista.scale
  barista.position=at
  barista.scale=Vector2.ONE*.62
  barista.draw_on(self)
  barista.position=original_position
  barista.scale=original_scale
 text_at(Vector2(570,820),"Коснись экрана, чтобы пропустить",25,Color("d6c7ae"))

func panel(color: Color) -> StyleBoxFlat:
 var style=StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(24)
 return style

func texture_polygon(points: PackedVector2Array) -> void:
 var uv=PackedVector2Array()
 for point in points: uv.append(point/Vector2(1600,900))
 draw_polygon(points,PackedColorArray([Color.WHITE]),uv,room)
func draw_cafe() -> void:
 barista.reaching=screen in ["","lesson"] and game.data.order.state=="BREWING" and game.brew.ready() and (dragging or cup_position.distance_to(CUP_HOME)>1)
 draw_texture_rect(room,Rect2(0,0,1600,900),false)
 if screen!="progress":
  barista.draw_on(self)
  guest.draw_on(self)
 draw_counter()
func draw_counter() -> void:
 # Equipment, complete countertop AND front fascia stay in front of every rig.
 texture_polygon(PackedVector2Array([Vector2(32,493),Vector2(224,493),Vector2(224,685),Vector2(260,685),Vector2(260,750),Vector2(331,718),Vector2(331,794),Vector2(218,843),Vector2(65,843),Vector2(65,670)]))
 texture_polygon(PackedVector2Array([Vector2(375,452),Vector2(478,408),Vector2(490,385),Vector2(654,384),Vector2(706,406),Vector2(709,680),Vector2(415,680),Vector2(415,568),Vector2(375,568)]))
 texture_polygon(PackedVector2Array([Vector2(760,309),Vector2(907,309),Vector2(907,420),Vector2(940,420),Vector2(940,518),Vector2(758,518)]))
 texture_polygon(PackedVector2Array([Vector2(0,681),Vector2(332,677),Vector2(698,649),Vector2(1218,617),Vector2(1220,900),Vector2(0,900)]))
func draw_arm(at: Vector2) -> void:
 # Same quadratic curve, origin and stroke colours as VISUAL-002/v9 drawArm().
 var origin=barista.position+Vector2(-57+sin(barista.clock*.73)*1.2,334)*barista.scale
 var delta=at-origin
 var control=origin+Vector2(delta.x*.42,delta.y*.3+32)
 var points=PackedVector2Array()
 for i in range(33):
  var t=i/32.0
  points.append((1-t)*(1-t)*origin+2*(1-t)*t*control+t*t*at)
 draw_polyline(points,Color("171318"),28,true)
 draw_polyline(points,Color("c58155"),22,true)
 for cap in [origin,at]:
  draw_circle(cap,14,Color("171318"))
  draw_circle(cap,11,Color("c58155"))
 var palm=PackedVector2Array()
 for i in range(65):
  var angle=i*TAU/64
  palm.append(at+Vector2(0,16)+Vector2(cos(angle)*18,sin(angle)*12))
 draw_colored_polygon(palm,Color("d39264"))
 draw_polyline(palm,Color("1d1717"),2.5,true)
func draw_cup(at: Vector2) -> void:
 draw_set_transform(at)
 draw_texture_rect(cup_textures[game.data.order.recipe],Rect2(-55,-110,110,157),false)
 for i in range(3):
  var points=PackedVector2Array()
  for j in range(14):
   var rise=fmod(visual_clock*22+i*17,60)
   points.append(Vector2((i-1)*12+sin(j*.4+visual_clock*2+i)*5,-55-j*3-rise*.35))
  draw_polyline(points,Color(.95,.91,.82,.25+.16*sin(visual_clock+i)),2,true)
 draw_set_transform(Vector2.ZERO)


func start_lesson() -> void:
 if repository.training: repository.end_training()
 if repository.begin_lesson():
  game=repository.session
  screen="lesson"
  paused=false
  lesson_completed=false
  shown_order=-1
  bar_progress=[0.0,0.0,0.0]
  sync_guest(true)
func finish_lesson() -> void:
 repository.end_training()
 game=repository.session
 screen="menu"
 paused=true
 shown_order=-1
 sync_guest(true)
func lesson_hint() -> String:
 if lesson_completed: return "Отлично! Заказ пройден. Нажми «Закончить»."
 if game.data.order.state=="PAYMENT": return "Теперь нажми на монеты рядом с гостем."
 if game.brew.ready(): return "Перетащи стакан гостю справа."
 var stage=game.brew.stage
 if game.brew.complete(stage): return "Готово. Тапни по следующему прибору."
 if game.brew.qualities()[stage]<1: return "Лишние тапы портят вкус. Переключи прибор."
 return ["Тапай по кофемолке до полной полосы.","Тапай по кофемашине до полной полосы.","Тапай по капучинатору до полной полосы."][stage]
