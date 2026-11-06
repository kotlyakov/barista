extends "res://ui/main.gd"
const Bridge=preload("res://ui/session_bridge.gd")
const Layout=preload("res://ui/guest_layout.gd")
const START_BUTTON=Rect2(1070,780,440,70)
const LESSON_BUTTON=Rect2(60,780,360,70)
const NEXT_BUTTON=Rect2(560,710,480,85)
const RECIPE_BUTTONS=[Rect2(32,110,215,52),Rect2(255,110,215,52),Rect2(478,110,215,52)]
const NAMES={"guest-01":"Бородач","guest-02":"Гаваец","guest-03":"Гость3","guest-04":"Гость4","guest-05":"Гость5","guest-06":"Гость6"}
const TABS=["Усиление","Приборы","Модули","Постоянники","Лига"]
var rigs={}
var slots={}
var shop_tab=0
var selected_module=""
var perf_elapsed=0.0
var pending_reminder=-1
var press_at=Vector2.ZERO
var speech_text=""
var speech_until=-1.0
var facepalm_until=-1.0
var speech_last={}
func _exit_tree():
 for rig in rigs.values():rig.free()
 super._exit_tree()
func _ready():
 repository=Bridge.new(save_directory);game=repository.session
 barista.enter("barista",true);sync_guest(true)
 screen="intro" if repository.ready else "error";paused=not repository.ready
 audio=load("res://ui/cafe_audio.gd").new();audio.begin_diagnostics(save_directory+"/audio-diagnostic.txt");add_child(audio);update_audio()
func finish_intro():
 intro_elapsed=3;screen="";paused=false;route_phase();update_audio();queue_redraw()
func route_phase():
 if repository.legacy or repository.training or not repository.ready:return
 if game.data.shift.phase in ["PREPARING","SUMMARY"]:screen="between"
 elif screen=="between":screen=""
func sync_guest(immediate=false):
 if repository==null:return
 if repository.legacy:super.sync_guest(immediate);return
 var present=[]
 for visit in game.data.visits:present.append(visit.id)
 for id in rigs.keys():
  if not id in present:rigs[id].free();rigs.erase(id);slots.erase(id)
 for visit in game.data.visits:
  if not rigs.has(visit.id):
   var slot=0
   while slot in slots.values():slot+=1
   var rig=Actor.new();rig.enter("beard" if int(visit.customer_id.right(2))%2==1 else "hawaii",true)
   rig.home=Layout.home(slot);rig.base_scale=0.43 if rig.actor_id=="beard" else 0.38
   rig.position=rig.home;rig.scale=Vector2.ONE*rig.base_scale
   if not immediate:rig.phase="wait_enter";rig.position=Vector2(1700,180)
   rigs[visit.id]=rig;slots[visit.id]=slot
  var actor=rigs[visit.id]
  if immediate and visit.state=="WAITING":actor.phase="idle";actor.position=actor.home;actor.scale=Vector2.ONE*actor.base_scale
  var emotion=game.data.profiles[visit.customer_id].mood
  if visit.state=="WAITING" and game.data.clock-visit.arrived_at>visit.patience_budget*0.7:emotion="impatient"
  actor.set_emotion({"very_unhappy":"angry","disgusted":"angry"}.get(emotion,emotion))
  actor.held_cup=visit.state!="WAITING" and visit.has("evaluation")
  if visit.has("evaluation"):actor.cup_recipe=content_sprite(visit.evaluation.contents)
  if visit.state=="WAITING" and actor.phase=="idle" and visit.get("wish_shown_at",0.0)<0:act("show_arrival_wish",[visit.id])
  if visit.state=="DEPARTING" and actor.phase=="idle":actor.phase="wait_leave"
 var corridor=false
 for actor in rigs.values():
  if actor.phase in ["enter","turn","leave"]:corridor=true
 if not corridor:
  for visit in game.data.visits:
   if visit.state=="DEPARTING" and rigs[visit.id].phase in ["wait_enter","wait_leave","idle"]:
    if rigs[visit.id].phase=="wait_enter":rigs[visit.id].phase="gone"
    else:rigs[visit.id].depart()
    corridor=true;break
 if not corridor:
  for actor in rigs.values():
   if actor.phase=="wait_enter":actor.phase="enter";actor.elapsed=0;break
func _process(delta: float):
 if not repository.ready:screen="error";paused=true;update_audio();queue_redraw();return
 if repository.legacy:
  super._process(delta)
  if not paused and screen!="intro" and repository.try_migrate():
   game=repository.session;guest.phase="gone";sync_guest(true);route_phase();update_audio()
  return
 if paused:return
 if screen=="intro":
  intro_elapsed=minf(3,intro_elapsed+delta)
  if intro_elapsed>=3:finish_intro()
  queue_redraw();return
 if not repository.ready:return
 if screen in ["menu","progress","between"]:return
 repository.advance(delta);game=repository.session;visual_clock+=delta;barista.step(delta);sync_guest()
 for id in rigs.keys():
  rigs[id].step(delta)
  if rigs[id].phase=="gone":act("finish_departure",[id])
 for i in range(3):bar_progress[i]=move_toward(bar_progress[i],clampf(float(game.cup.taps[i])/game.cup.targets[i],0,1),delta*3.5)
 if game.data.clock>=facepalm_until:barista.set_emotion("neutral")
 if not dragging:cup_position=cup_position.lerp(CUP_HOME,minf(1,delta*14))
 if OS.is_debug_build() and game.data.visits.size()==5:
  perf_elapsed+=delta
  if perf_elapsed>=5:
   perf_elapsed=0
   var file=FileAccess.open(save_directory+"/v2-performance.json",FileAccess.WRITE)
   if file!=null:
    file.store_string(JSON.stringify({"fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"visits":5,"clock":game.data.clock}));file.close()
 route_phase();queue_redraw()
func act(method: String,args: Array=[]) -> bool:
 var result=repository.apply(method,args);game=repository.session
 if result and audio:
  if method=="tap":audio.effect(["grind","brew","steam"][args[0]])
  elif method=="collect":audio.effect("coins")
 if not repository.legacy:
  if method=="tap" and args[0]==1 and not result and game.can_prepare() and game.cup.taps[0]==0:speak("Ой! Зёрна-то не помолола!",true)
  if method=="take_cup" and result:
   var line=game.cup.pickup_line()
   if line!="":speak(line)
 if repository.error!="":message="Действие не сохранено. Прогресс сохранён до него."
 return result
func open_menu():
 pending_reminder=-1
 if not repository.ready:screen="error";paused=true;dragging=false;update_audio();queue_redraw();return
 if repository.legacy:super.open_menu();return
 repository.suspend();dragging=false;cup_position=CUP_HOME;screen="menu";paused=true;update_audio();queue_redraw()
func resume_game():
 paused=false;screen="lesson" if repository.training else "";route_phase();update_audio();queue_redraw()
func visit_drop_rect(id: int) -> Rect2:
 var visit=game.find_visit(id)
 if visit.is_empty() or visit.state!="WAITING" or not rigs.has(id) or rigs[id].phase!="idle":return Rect2()
 return Layout.drop(int(slots[id]))
func visit_coin_rect(id: int) -> Rect2:return Layout.coins(int(slots[id])) if slots.has(id) else Rect2()
func cancel_drag(keep_owner=false):
 dragging=false;pending_reminder=-1;cup_position=CUP_HOME;repository.cancel_carry()
 if not keep_owner:pointer.cancel()
func _notification(what: int):
 if repository==null:return
 if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:cancel_drag();open_menu()
func _input(event: InputEvent):
 if repository==null:return
 if not repository.ready:
  screen="error";paused=true
  var error_action=pointer.route(event)
  if error_action.get("action")=="press" and MENU_REPORT.has_point(error_action.position):DisplayServer.clipboard_set(repository.error)
  return
 if repository.legacy:
  var previous=pointer.active
  super._input(event)
  if previous==-2 and event is InputEventScreenTouch and event.pressed and not event.canceled and pointer.active==-2:pointer.active=event.index
  if previous==-2 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.device!=InputEvent.DEVICE_ID_EMULATION and pointer.active==-2:pointer.active=-1
  return
 var action=pointer.route(event)
 if action.is_empty():return
 var point=action.position
 if action.action=="cancel":cancel_drag();queue_redraw();return
 if screen=="intro":
  if action.action=="press":finish_intro()
  return
 if action.action=="press":
  if screen=="menu":
   if MENU_RESUME.has_point(point) and repository.ready:resume_game()
   elif MENU_SOUND.has_point(point) and repository.ready:
    if repository.set_preference("muted",not audio.muted):audio_safe_start=false
    update_audio()
   elif MENU_PROGRESS.has_point(point) and repository.ready:screen="progress"
   elif MENU_REPORT.has_point(point):DisplayServer.clipboard_set(audio.report());report_copied=true
   queue_redraw();return
  if screen=="progress":
   if BACK_BUTTON.has_point(point):screen="menu"
   elif LESSON_BUTTON.has_point(point):start_lesson()
   queue_redraw();return
  if paused or not repository.ready:return
  if MENU_BUTTON.has_point(point):open_menu();return
  if screen=="between":shop_input(point);queue_redraw();return
  if repository.training and Rect2(1100,800,460,65).has_point(point):finish_lesson();return
  repository.advance(0);game=repository.session
  var coin_hit=false
  for payment in game.data.payments:
   if payment.state=="PENDING" and visit_coin_rect(payment.visit_id).has_point(point):
    if act("collect",[payment.id]) and screen=="lesson":lesson_completed=true;repository.set_preference("tutorial_seen",true)
    coin_hit=true;break
  if not coin_hit:
   var recipe_hit=false
   for i in range(3):
    if RECIPE_BUTTONS[i].has_point(point):act("select_recipe",[RECIPE_NAMES.keys()[i]]);recipe_hit=true
   if not recipe_hit:
    if not game.cup.is_empty() and Rect2(cup_position-Vector2(60,110),Vector2(120,165)).has_point(point):
     if act("take_cup"):dragging=true;cup_grab_offset=cup_position-point
    else:
     var hit=false
     for i in range(3):
      if station_rects[i].has_point(point):act("tap",[i]);hit=true;break
     if not hit:
      for visit in game.data.visits:
       if visit_drop_rect(visit.id).has_point(point):pending_reminder=visit.id;press_at=point;break
 elif action.action=="move":
  if pending_reminder>=0 and point.distance_to(press_at)>12:pending_reminder=-1
  if dragging and not paused:cup_position=point+cup_grab_offset
 elif action.action=="release" and dragging:
  dragging=false;cup_position=point+cup_grab_offset
  var delivered=false
  if not paused:
   for visit in game.data.visits:
    if visit_drop_rect(visit.id).has_point(cup_position):delivered=act("deliver",[game.data.cup_id,visit.id]);break
  repository.cancel_carry()
  if delivered:bar_progress=[0.0,0.0,0.0]
 elif action.action=="release" and pending_reminder>=0:
  if not paused and point.distance_to(press_at)<=12 and visit_drop_rect(pending_reminder).has_point(point):act("remind_wish",[pending_reminder])
  pending_reminder=-1
 queue_redraw()
func shop_input(point: Vector2):
 var shift=game.data.shift
 if shift.phase=="SUMMARY":
  if NEXT_BUTTON.has_point(point):act("finish_summary",[shift.summary_id]);shop_message="";sync_guest(true)
  return
 if START_BUTTON.has_point(point):
  if act("start_shift",[shift.day_number]):screen="";sync_guest();update_audio()
  else:shop_message="Не хватает монет на обслуживание. Сними быстрый привод."
  return
 for i in range(5):
  if tab_rect(i).has_point(point):shop_tab=i;selected_module="";shop_message="";return
 var e=game.data.economy;var C=game.Career
 if shop_tab==0:
  for i in range(3):
   if offer_rect(i).has_point(point):shop_message="Усиление куплено" if act("buy_perk",[e.offers[i],shift.day_number]) else "Выбор уже сделан или не хватает монет"
  if Rect2(60,780,360,70).has_point(point):shop_message="Копим на улучшения" if act("skip_perk",[shift.day_number]) else "Выбор уже сохранён"
 elif shop_tab==1:
  for i in range(4):
   if gear_rect(i).has_point(point):
    var id=["grind","brew","milk","ads"][i]
    shop_message="Улучшение куплено" if act("buy_equipment",[id,int(game.data.upgrades[id])]) else "Максимум или не хватает монет"
 elif shop_tab==2:
  for i in range(3):
   if offer_rect(i).has_point(point):
    var id=C.MODULES.keys()[i]
    if not id in e.owned_modules:shop_message="Модуль куплен" if act("buy_module",[id]) else "Недостаточно монет"
    else:selected_module=id;shop_message="Нажми на слот для установки"
  for slot in range(2):
   if Rect2(370+slot*450,630,410,65).has_point(point) and selected_module!="":shop_message="Установлен" if act("equip_module",[selected_module,slot]) else "Этот модуль уже установлен"
   if Rect2(370+slot*450,710,410,50).has_point(point):act("remove_module",[slot])
 elif shop_tab==3:
  for i in range(6):
   var id=NAMES.keys()[i];var rect=regular_rect(i)
   if Rect2(rect.position+Vector2(12,100),Vector2(270,40)).has_point(point):shop_message="Угощение оплачено на следующий визит" if act("reserve_gift",[id]) else "Уже оплачено или недостаточно монет"
   if Rect2(rect.position+Vector2(12,145),Vector2(270,40)).has_point(point):shop_message="Награда получена" if act("claim_goal",[id,int(e.claimed[id])]) else "Личная цель ещё не выполнена"
 elif shop_tab==4:
  if Rect2(560,570,480,70).has_point(point):shop_message="Лига повышена" if act("promote_league",[int(e.league)]) else "Нужно больше известности или достигнута верхняя лига"
func draw_button(rect: Rect2,label: String,active=true) -> void:
 var size=25
 while size>14 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-32:size-=1
 draw_style_box(panel(Color("426951") if active else Color("2b353d")),rect)
 text_at(rect.position+Vector2(16,rect.size.y*.5+size*.35),label,size,Color("efdec0") if active else Color("a9a7a2"))
func tab_rect(i: int) -> Rect2:return Rect2(70+i*296,230,280,55)
func offer_rect(i: int) -> Rect2:return Rect2(100+i*490,330,450,230)
func gear_rect(i: int) -> Rect2:return Rect2(290+(i%2)*530,330+floori(i/2.0)*180,490,155)
func regular_rect(i: int) -> Rect2:return Rect2(320+(i%3)*315,305+floori(i/3.0)*205,300,190)
func wrapped(at: Vector2,value: String,width: float,size=22):
 var words=value.split(" ");var line="";var y=at.y
 for word in words:
  if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
   text_at(Vector2(at.x,y),line,size);line="";y+=size+7
  line+=word+" "
 text_at(Vector2(at.x,y),line,size)
func _draw():
 if repository==null:return
 if not repository.ready:
  draw_texture_rect(room,Rect2(0,0,1600,900),false);draw_rect(Rect2(20,110,1560,770),Color("111d27f5"))
  wrapped(Vector2(350,300),"Не удалось загрузить или перенести прогресс. Он не сброшен. Перезапусти игру для повторной попытки.",900,30)
  draw_button(MENU_REPORT,"Скопировать отчёт");return
 if repository.legacy:super._draw();return
 draw_cafe()
 if screen=="intro":draw_intro();return
 draw_style_box(panel(Color("111922dc")),Rect2(22,18,1556,82));text_at(Vector2(48,67),"ПУТЬ БАРИСТЫ",27)
 text_at(Vector2(360,66),str(game.data.money)+" монет",29,Color("ebbc76"));text_at(Vector2(760,66),"День "+str(game.data.get("shift",{}).get("day_number",1)),25)
 var minutes=game.clock_minutes();text_at(Vector2(1070,66),"%02d:%02d"%[minutes/60,minutes%60],26)
 for i in range(3):draw_line(Vector2(1468,42+i*15),Vector2(1520,42+i*15),Color("eddfc8"),4,true)
 if screen=="between":draw_between()
 elif screen=="progress":draw_progress()
 elif screen=="menu":
  draw_rect(Rect2(0,100,1600,800),Color(.025,.035,.045,.85));text_at(Vector2(675,310),"ПАУЗА",48)
  draw_button(MENU_RESUME,"Продолжить",repository.ready);draw_button(MENU_SOUND,"Звук выключен" if audio.muted else "Звук включён",repository.ready);draw_button(MENU_PROGRESS,"Прогресс и обучение",repository.ready);draw_button(MENU_REPORT,"Скопировать отчёт")
  if not repository.ready:wrapped(Vector2(350,220),"Не удалось загрузить прогресс. Он не перезаписан. Перезапусти игру для повторной попытки.",900,26)
 else:draw_play()
 if repository.error!="":text_at(Vector2(35,882),"Не удалось сохранить действие. Прогресс не перезаписан.",20,Color("ee9a86"))
func operation_color(station: int) -> Color:
 var extra=int(game.cup.taps[station])-int(game.cup.targets[station])
 if extra>0:return Color("ee9a86").lerp(Color("650b15"),float(clampi(extra,1,10)-1)/9)
 return Color("ebbc76") if extra==0 else Color("82d4b5")
func content_sprite(contents: String) -> String:return contents if contents in RECIPE_NAMES else "cappuccino"
func content_name(contents: String) -> String:return RECIPE_NAMES.get(contents,{"grounds":"Помол","milk":"Молоко","milk_grounds":"Молоко и помол","coffee_milk":"Кофе с молоком","empty":"Пусто"}.get(contents,contents))
func current_cup_label() -> String:return content_name(game.cup.contents())
func visit_speech(visit: Dictionary) -> String:
 if visit.state=="WAITING" and visit.get("wish_shown_at",0.0)>=0 and game.data.clock<visit.bubble_until:return RECIPE_NAMES[visit.wish_recipe]
 if visit.has("evaluation") and game.data.clock<visit.get("reaction_until",0.0):return game.data.profiles[visit.customer_id].last_reaction
 return ""
func speak(line: String,facepalm=false):
 if game.data.clock-float(speech_last.get(line,-100))<2:return
 speech_last[line]=game.data.clock;speech_text=line;speech_until=game.data.clock+3
 if facepalm:facepalm_until=game.data.clock+1.5;barista.set_emotion("unhappy")
func draw_bubble(rect: Rect2,line: String,mouth: Vector2,size=18):
 draw_style_box(panel(Color("eadbc0")),rect)
 var edge=Vector2(clampf(mouth.x,rect.position.x+12,rect.end.x-12),rect.end.y)
 draw_colored_polygon(PackedVector2Array([edge-Vector2(7,0),edge+Vector2(7,0),mouth]),Color("eadbc0"))
 var words=line.split(" ");var current="";var y=rect.position.y+size+9
 for word in words:
  if font.get_string_size(current+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-16:
   text_at(Vector2(rect.position.x+8,y),current,size,Color("302628"));current="";y+=size+5
  current+=word+" "
 text_at(Vector2(rect.position.x+8,y),current,size,Color("302628"))
func draw_play():
 if repository.legacy:super.draw_play();return
 for i in range(3):
  draw_button(RECIPE_BUTTONS[i],("✓ " if game.cup.recipe==RECIPE_NAMES.keys()[i] else "")+RECIPE_NAMES.values()[i],game.cup.recipe==RECIPE_NAMES.keys()[i])
  var color=operation_color(i)
  draw_texture(outlines[i],Vector2.ZERO,Color(color,0.45))
  draw_style_box(panel(Color("151c26cc")),Rect2(BAR_POSITIONS[i],Vector2(176,10)))
  if bar_progress[i]>0:draw_style_box(panel(color),Rect2(BAR_POSITIONS[i],Vector2(176*bar_progress[i],10)))
 for visit in game.data.visits:
  if not rigs.has(visit.id) or rigs[visit.id].phase in ["wait_enter","gone"]:continue
  var slot=int(slots[visit.id]);var bubble=Layout.bubble(slot)
  var line=visit_speech(visit)
  if line!="":
   draw_bubble(bubble,NAMES[visit.customer_id]+": "+line,rigs[visit.id].position+Vector2(0,10)*rigs[visit.id].scale,17)
  else:text_at(bubble.position+Vector2(4,22),NAMES[visit.customer_id],20)
 for payment in game.data.payments:
  if payment.state!="PENDING" or not slots.has(payment.visit_id):continue
  var rect=visit_coin_rect(payment.visit_id);draw_circle(rect.get_center(),26,Color("dba74a"));text_at(rect.position+Vector2(12,44),str(payment.amount),23,Color("302628"))
 if not game.cup.is_empty():
  if barista.reaching:draw_arm(cup_position)
  draw_cup(cup_position)
  if not dragging:text_at(CUP_HOME+Vector2(-90,90),current_cup_label(),20)
 if game.data.clock<facepalm_until and not dragging:draw_arm(barista.position+Vector2(5,35)*barista.scale)
 if game.data.clock<speech_until:draw_bubble(Rect2(370,180,550,85),speech_text,barista.position+Vector2(30,25)*barista.scale,22)
 if repository.training:draw_button(Rect2(1100,800,460,65),"Закончить обучение")
 if screen=="lesson":wrapped(Vector2(30,225),lesson_hint(),600,21)
func draw_between():
 draw_rect(Rect2(20,115,1560,755),Color("111d27f5"));var shift=game.data.shift
 text_at(Vector2(60,154),"Техническое оформление · механики карьеры",19,Color("a7b9c4"))
 if shift.phase=="SUMMARY":
  text_at(Vector2(470,310),"Смена завершена",44)
  text_at(Vector2(470,380),"Выдано: "+str(shift.stats.served)+" · Хороших: "+str(shift.stats.good),28)
  text_at(Vector2(470,435),"Собрано: "+str(shift.stats.earned)+" монет",30,Color("ebbc76"))
  text_at(Vector2(470,485),"Ушло без кофе: "+str(shift.stats.left),25);draw_button(NEXT_BUTTON,"Следующий день");return
 var C=game.Career;var e=game.data.economy
 wrapped(Vector2(60,194),C.EVENTS[shift.event_id],1460,23)
 for i in range(5):draw_button(tab_rect(i),TABS[i],shop_tab==i)
 if shop_tab==0:
  for i in range(3):
   var id=e.offers[i];var item=C.PERKS[id];var rect=offer_rect(i);draw_style_box(panel(Color("20323d")),rect)
   text_at(rect.position+Vector2(20,42),item.name,26);wrapped(rect.position+Vector2(20,90),item.description,405,22)
   text_at(rect.position+Vector2(20,205),str(item.price)+" монет"+(" · Куплено" if e.choice==id else ""),25,Color("ebbc76"))
  draw_button(LESSON_BUTTON,"Пропустить покупку",e.choice=="")
 elif shop_tab==1:
  for i in range(4):
   var id=["grind","brew","milk","ads"][i];var level=int(game.data.upgrades[id]);var rect=gear_rect(i);draw_style_box(panel(Color("20323d")),rect)
   text_at(rect.position+Vector2(20,40),["Жернова","Кофемашина","Молоко","Реклама"][i]+" · "+str(level)+"/3",26)
   text_at(rect.position+Vector2(20,82),"Гости чаще" if id=="ads" else "На1 тап меньше за уровень",22)
   text_at(rect.position+Vector2(20,125),"Максимум" if level==3 else str(C.equipment_price(game.data,level))+" монет",25,Color("ebbc76"))
 elif shop_tab==2:
  for i in range(3):
   var id=C.MODULES.keys()[i];var item=C.MODULES[id];var rect=offer_rect(i);draw_style_box(panel(Color("20323d")),rect)
   text_at(rect.position+Vector2(20,40),item.name,26);wrapped(rect.position+Vector2(20,85),item.description,405,22)
   text_at(rect.position+Vector2(20,205),"Выбрать" if id in e.owned_modules else str(item.price)+" монет",24,Color("ebbc76"))
  for slot in range(2):
   var id=e.equipped_modules[slot];draw_button(Rect2(370+slot*450,630,410,65),"Слот "+str(slot+1)+": "+("Пусто" if id=="" else C.MODULES[id].name))
   draw_button(Rect2(370+slot*450,710,410,50),"Снять бесплатно",id!="")
 elif shop_tab==3:
  for i in range(6):
   var id=NAMES.keys()[i];var rect=regular_rect(i);draw_style_box(panel(Color("20323d")),rect)
   text_at(rect.position+Vector2(12,28),NAMES[id]+" · "+RECIPE_NAMES[game.data.profiles[id].favorite],19)
   text_at(rect.position+Vector2(12,58),"Цель "+str(e.goals[id])+"/"+str(3 if e.claimed[id]==0 else 6)+" → "+str(C.GOAL_REWARDS[mini(1,int(e.claimed[id]))])+" монет",18)
   text_at(rect.position+Vector2(12,86),"Скидка на приборы5/10%" if i==0 else "Друзья приходят чаще" if i==1 else "Награда за любимый кофе",18)
   draw_button(Rect2(rect.position+Vector2(12,100),Vector2(270,40)),"Угощение оплачено" if e.gifts[id] else "След. визит · "+str(game.PRICES[game.data.profiles[id].favorite]))
   draw_button(Rect2(rect.position+Vector2(12,145),Vector2(270,40)),"Забрать награду" if e.claimed[id]<2 else "Цели выполнены",e.claimed[id]<2)
  text_at(Vector2(70,740),"Угощение оплачивает следующий визит. Доверие меняется только от напитка.",21)
 else:
  text_at(Vector2(500,380),"Известность: "+str(e.fame)+" · Лига "+str(int(e.league)+1),36)
  wrapped(Vector2(500,440),"Новая лига повышает поток и цены. Переход только по твоему выбору. Порог следующей: "+(str(C.LEAGUE_FAME[int(e.league)+1]) if e.league<2 else "достигнута верхняя лига"),650,24)
  draw_button(Rect2(560,570,480,70),"Повысить лигу",e.league<2)
 if shop_message!="":wrapped(Vector2(60,740 if shop_tab!=2 else 610),shop_message,1400,22)
 draw_button(START_BUTTON,"Открыть смену")
func draw_progress():
 if repository.legacy:super.draw_progress();return
 draw_rect(Rect2(20,110,1560,770),Color("111d27ef"));draw_button(BACK_BUTTON,"‹ Назад в меню")
 text_at(Vector2(420,230),"Прогресс карьеры",42);text_at(Vector2(420,300),"День "+str(game.data.shift.day_number)+" · "+str(game.data.money)+" монет",30)
 text_at(Vector2(420,360),"Известность "+str(game.data.economy.fame)+" · Лига "+str(int(game.data.economy.league)+1),28)
 wrapped(Vector2(420,440),"Приборы, модули и угощения доступны между сменами. Обучение не меняет деньги, историю гостей и поток основной игры.",900,26)
 draw_button(LESSON_BUTTON,"Потренироваться")
func start_lesson():
 if repository.begin_lesson():game=repository.session;screen="lesson";paused=false;lesson_completed=false;clear_rigs();sync_guest(true);bar_progress=[0.0,0.0,0.0];update_audio()
func finish_lesson():
 repository.end_training();game=repository.session;clear_rigs();sync_guest(true);screen="menu";paused=true;cancel_drag(true);update_audio()
func clear_rigs():
 for rig in rigs.values():rig.free()
 rigs.clear();slots.clear()
func lesson_hint() -> String:
 if repository.legacy:return super.lesson_hint()
 return "Готовь в любом порядке. Варка требует хотя бы одного тапа помола. Можно отдать любой стакан любому гостю; монеты нужно собрать." if not lesson_completed else "Заказ пройден! Можно продолжить тренировку или закончить."
func draw_cafe():
 if repository==null:return
 if repository.legacy:super.draw_cafe();return
 barista.reaching=screen in ["","lesson"] and (game.data.clock<facepalm_until or not game.cup.is_empty() and (dragging or cup_position.distance_to(CUP_HOME)>1))
 draw_texture_rect(room,Rect2(0,0,1600,900),false);barista.draw_on(self)
 if screen!="progress":
  for rig in rigs.values():
   if not rig.phase in ["wait_enter","gone"]:rig.draw_on(self)
 draw_counter()
func draw_cup(at: Vector2):
 if repository.legacy:super.draw_cup(at);return
 draw_set_transform(at);draw_texture_rect(cup_textures[content_sprite(game.cup.contents())],Rect2(-55,-110,110,157),false)
 var heat=game.cup.temperature(game.data.clock)
 if heat>0:
  for i in range(3):
   var points=PackedVector2Array()
   for j in range(14):points.append(Vector2((i-1)*12+sin(j*.4+visual_clock*2+i)*5,-55-j*3-fmod(visual_clock*22+i*17,60)*.35))
   draw_polyline(points,Color(.95,.91,.82,heat*.4),2,true)
 draw_set_transform(Vector2.ZERO)
