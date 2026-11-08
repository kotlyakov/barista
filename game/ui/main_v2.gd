extends "res://ui/main.gd"
const Bridge=preload("res://ui/session_bridge.gd")
const Layout=preload("res://ui/guest_layout.gd")
const Charcoal = preload("res://ui/charcoal_intermission.gd")
const CAFE = preload("res://content/art/charcoal/room.webp")
const CHARCOAL_CUP = preload("res://content/art/charcoal/cup.webp")
const VISITORS = [
 preload("res://content/art/charcoal/guest-0.webp"), preload("res://content/art/charcoal/guest-1.webp"),
 preload("res://content/art/charcoal/guest-2.webp"), preload("res://content/art/charcoal/guest-3.webp"),
 preload("res://content/art/charcoal/guest-4.webp")
]
const V2_CUP_HOME = Vector2(659, 827)
const STATIONS = [Rect2(808, 490, 202, 373), Rect2(1197, 485, 377, 378), Rect2(1010, 527, 187, 336)]
const STATION_BARS = [Rect2(823, 849, 158, 14), Rect2(1265, 849, 225, 14), Rect2(1037, 849, 164, 14)]
const STATION_COLORS = [Color("cbd16b"), Color("ffb546"), Color("40eafa")]
const PERFECT_COLOR = Color("49ff24")
const OVERTAP_COLOR = Color("f33c31")
const V2_MENU = Rect2(1490, 0, 110, 78)
const START_BUTTON = Rect2(1145, 783, 350, 72)
const EXTRA_BUTTON = Rect2(1318, 0, 165, 48)
const EQUIPMENT_IDS = ["grind", "milk", "brew", "ads"]
const LESSON_BUTTON=Rect2(60,780,360,70)
const NEXT_BUTTON=Rect2(560,710,480,85)
const CARTON_RECT=Rect2(1038,360,130,167)
const MENU_DISCARD=Rect2(560,785,480,80)
const CUP_GRIP=preload("res://content/art/charcoal/cup-grip.svg")
const CARTON=preload("res://content/art/charcoal/milk-carton.svg")
const DROP=preload("res://content/art/charcoal/milk-drop.svg")
const GUEST_IDS=["guest-01","guest-02","guest-03","guest-04","guest-05","guest-06"]
const EXTRA_TABS = ["Модули", "Постоянники", "Лига"]
var rigs={}
var slots={}
var shop_tab=0
var pending_shift_day=0
var fold_elapsed=0.0
var stroke_progress=1.0
var purchase_animation: Dictionary={}
const FOLD_SECONDS=0.32
const PURCHASE_SECONDS=0.48
const COIN_TRAVEL=0.40
const COIN_ANIMATION=0.88
const WALLET_COIN=Vector2(414,24)
var coin_flights: Array[Dictionary]=[]
var selected_module=""
var perf_elapsed=0.0
var pending_reminder=-1
var press_at=Vector2.ZERO
var speech_text=""
var speech_until=-1.0
var facepalm_until=-1.0
var speech_last={}
var main_rigs={}
var main_slots={}
var main_bars=[]
var bar_colors=STATION_COLORS.duplicate()
var sheet_font=FontVariation.new()
func _exit_tree():
 for rig in rigs.values():rig.free()
 for rig in main_rigs.values():rig.free()
 super._exit_tree()
func _ready():
 sheet_font.base_font=font
 sheet_font.variation_transform=Transform2D(Vector2(1,0),Vector2(-0.22,1),Vector2.ZERO)
 repository=Bridge.new(save_directory);game=repository.session
 barista.enter("barista",true);sync_guest(true)
 screen="intro" if repository.ready else "error";paused=not repository.ready
 if repository.ready and not repository.legacy:
  use_charcoal_layout()
  screen=""
  route_phase()
 audio=load("res://ui/cafe_audio.gd").new();audio.begin_diagnostics(save_directory+"/audio-diagnostic.txt");add_child(audio);update_audio()
func use_charcoal_layout() -> void:
 station_rects = STATIONS.duplicate()
 cup_position = V2_CUP_HOME

func finish_intro():
 if pending_shift_day>0:
  var day=pending_shift_day
  pending_shift_day=0
  if not act("start_shift",[day]):
   screen="between"
   shop_message="Не удалось начать смену. Проверь баланс и сохранение."
   update_audio()
   queue_redraw()
   return
  shop_tab=0
  shop_message=""
  purchase_animation.clear()
  sync_guest()
 intro_elapsed=3;screen="";paused=false;route_phase();update_audio();queue_redraw()

func open_shop_tab(index: int) -> void:
 if shop_tab==index:return
 shop_tab=index
 selected_module=""
 shop_message=""
 stroke_progress=0.0
 if audio:audio.effect("pencil",true)

func buy_on_sheet(method: String,args: Array,passive_row=-1) -> bool:
 var old_balance: int=game.data.money
 var shown_balance: int=display_balance()
 if not act(method,args):return false
 purchase_animation={"elapsed":0.0,"from":shown_balance,"amount":old_balance-int(game.data.money),"row":passive_row}
 return true

func purchase_progress() -> float:
 return smoothstep(0.0,PURCHASE_SECONDS,float(purchase_animation.get("elapsed",PURCHASE_SECONDS)))

func display_balance() -> int:
 return roundi(lerpf(float(purchase_animation.get("from",game.data.money)),float(game.data.money),purchase_progress()))
func collection_progress(elapsed: float) -> float:
 return smoothstep(COIN_TRAVEL,COIN_ANIMATION,elapsed)

func collection_balance() -> int:
 var pending=0.0
 for flight in coin_flights:
  pending+=float(flight.amount)*(1.0-collection_progress(flight.elapsed))
 return int(game.data.money)-roundi(pending)

func route_phase():
 if repository.legacy or repository.training or not repository.ready:return
 if game.data.shift.phase in ["PREPARING","SUMMARY"]:
  if coin_flights.is_empty():screen="between"
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
   var rig=Actor.new();rig.phase="idle"
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
   if visit.state=="DEPARTING" and rigs[visit.id].phase in ["wait_enter","wait_leave","idle"] and visit_speech(visit)=="":
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
   game=repository.session;guest.phase="gone";use_charcoal_layout();sync_guest(true);route_phase();update_audio()
  return
 if paused:return
 if screen=="fold":
  fold_elapsed=minf(FOLD_SECONDS,fold_elapsed+delta)
  if fold_elapsed>=FOLD_SECONDS:
   screen="intro"
   intro_elapsed=0
  queue_redraw();return
 if screen=="between":
  if stroke_progress<1.0 or not purchase_animation.is_empty():
   stroke_progress=minf(1.0,stroke_progress+delta/.26)
   if not purchase_animation.is_empty():
    purchase_animation.elapsed+=delta
    if purchase_animation.elapsed>=PURCHASE_SECONDS:purchase_animation.clear()
   queue_redraw()
  return
 if screen=="intro":
  intro_elapsed=minf(3,intro_elapsed+delta)
  if intro_elapsed>=3:finish_intro()
  queue_redraw();return
 if not repository.ready:return
 if screen in ["menu","progress","between"]:return
 repository.advance(delta);game=repository.session;visual_clock+=delta;barista.step(delta);sync_guest()
 for flight in coin_flights:flight.elapsed+=delta
 while not coin_flights.is_empty() and coin_flights[0].elapsed>=COIN_ANIMATION:coin_flights.pop_front()
 for id in rigs.keys():
  rigs[id].step(delta)
  if rigs[id].phase=="gone":act("finish_departure",[id])
 for i in range(3):
  bar_progress[i]=move_toward(bar_progress[i],clampf(float(game.cup.taps[i])/game.cup.targets[i],0,1),delta*3.5)
  bar_colors[i]=bar_colors[i].lerp(operation_color(i),1.0-exp(-delta*22.0))
 if game.data.clock>=facepalm_until:barista.set_emotion("neutral")
 if not dragging:cup_position=cup_position.lerp(V2_CUP_HOME,minf(1,delta*14))
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
  elif method=="add_milk":audio.effect("pour")
  elif method=="collect":audio.effect("coins")
 if not repository.legacy:
  if method=="tap" and args[0]==2 and not result and game.can_prepare() and game.cup.milk_doses==0:speak("Сначала молоко из коробки.")
  if method=="tap" and args[0]==1 and not result and game.can_prepare() and game.cup.taps[0]==0:speak("Ой! Зёрна-то не помолола!",true)
 if repository.error!="":message="Действие не сохранено. Прогресс сохранён до него."
 return result
func open_menu():
 pending_reminder=-1
 pending_shift_day=0
 if not repository.ready:screen="error";paused=true;dragging=false;update_audio();queue_redraw();return
 if repository.legacy:super.open_menu();return
 repository.suspend();dragging=false;cup_position=V2_CUP_HOME;screen="menu";paused=true;update_audio();queue_redraw()
func resume_game():
 paused=false;screen="lesson" if repository.training else "";route_phase();update_audio();queue_redraw()
func visit_drop_rect(id: int) -> Rect2:
 var visit=game.find_visit(id)
 if visit.is_empty() or visit.state!="WAITING" or not rigs.has(id) or rigs[id].phase!="idle":return Rect2()
 return Layout.drop(int(slots[id]))
func visit_coin_rect(id: int) -> Rect2:return Layout.coins(int(slots[id])) if slots.has(id) else Rect2()
func cancel_drag(keep_owner=false):
 dragging=false;pending_reminder=-1;cup_position=CUP_HOME if repository.legacy else V2_CUP_HOME;repository.cancel_carry()
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
 if screen=="fold":return
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
   elif MENU_DISCARD.has_point(point) and can_discard_cup():
    if act("discard_cup"):bar_progress=[0.0,0.0,0.0];resume_game()
   queue_redraw();return
  if screen=="progress":
   if BACK_BUTTON.has_point(point):screen="menu"
   elif LESSON_BUTTON.has_point(point):start_lesson()
   queue_redraw();return
  if paused or not repository.ready:return
  if V2_MENU.has_point(point):open_menu();return
  if screen=="between":shop_input(point);queue_redraw();return
  if repository.training and Rect2(1100,800,460,65).has_point(point):finish_lesson();return
  repository.advance(0);game=repository.session
  var coin_hit=false
  for payment in game.data.payments:
   if payment.state=="PENDING" and visit_coin_rect(payment.visit_id).has_point(point):
    var source=visit_coin_rect(payment.visit_id).get_center()
    if act("collect",[payment.id]):
     coin_flights.append({"source":source,"elapsed":0.0,"amount":payment.amount,"tip":payment.tip})
     if screen=="lesson":lesson_completed=true;repository.set_preference("tutorial_seen",true)
    coin_hit=true;break
  if not coin_hit:
   if CARTON_RECT.has_point(point) and game.cup.milk_doses>=0:
    act("add_milk")
   elif not game.cup.is_empty() and Rect2(cup_position-Vector2(56,142),Vector2(112,158)).has_point(point):
    if act("take_cup"):dragging=true;cup_grab_offset=cup_position-point
   else:
    var hit=false
    for i in range(3):
     if station_rects[i].has_point(point) or STATION_BARS[i].grow(4).has_point(point):act("tap",[i]);hit=true;break
    if not hit:
     for visit in game.data.visits:
      if visit_drop_rect(visit.id).has_point(point):pending_reminder=visit.id;press_at=point;break
 elif action.action=="move":
  if pending_reminder>=0 and point.distance_to(press_at)>12:pending_reminder=-1
  if dragging and not paused:cup_position=point+cup_grab_offset
 elif action.action=="release" and dragging:
  var attempted_cup=int(game.data.cup_id)
  dragging=false;cup_position=point+cup_grab_offset
  var delivered=false
  if not paused:
   for visit in game.data.visits:
    if visit_drop_rect(visit.id).has_point(cup_position):delivered=act("deliver",[game.data.cup_id,visit.id]);break
  record_drop_trace(attempted_cup,delivered)
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
  if game.data.money<game.Career.effects(game.data).maintenance:
   shop_message="Не хватает монет на обслуживание. Сними быстрый привод."
  else:
   pending_shift_day=shift.day_number
   fold_elapsed=0
   screen="fold"
   update_audio()
  return
 if EXTRA_BUTTON.has_point(point):
  open_shop_tab(0 if shop_tab>=3 else 3);return
 var first_tab=3 if shop_tab>=3 else 0
 for i in range(first_tab,first_tab+3):
  if tab_rect(i).has_point(point):open_shop_tab(i);return
 var e=game.data.economy;var C=game.Career
 if shop_tab==0:
  for i in range(3):
   if offer_rect(i).has_point(point):shop_message="Усиление куплено" if buy_on_sheet("buy_perk",[e.offers[i],shift.day_number]) else "Выбор уже сделан или не хватает монет"
 elif shop_tab==1:
  for i in range(4):
   if gear_rect(i).has_point(point):
    var id=EQUIPMENT_IDS[i]
    shop_message="Улучшение куплено" if buy_on_sheet("buy_equipment",[id,int(game.data.upgrades[id])]) else "Максимум или не хватает монет"
 elif shop_tab==2:
  for i in range(Charcoal.PASSIVES.size()):
   if Charcoal.passive_button_rect(i).has_point(point):
    var id: String=game.Career.PASSIVE_IDS[i]
    shop_message="Пассивка улучшена" if buy_on_sheet("buy_passive",[id,game.Career.passive_level(game.data,id)],i) else "Максимум или не хватает монет"
    return
 elif shop_tab==3:
  for i in range(3):
   if offer_rect(i).has_point(point):
    var id=C.MODULES.keys()[i]
    if not id in e.owned_modules:shop_message="Модуль куплен" if act("buy_module",[id]) else "Недостаточно монет"
    else:selected_module=id;shop_message="Нажми на слот для установки"
  for slot in range(2):
   if Rect2(370+slot*450,630,410,65).has_point(point) and selected_module!="":shop_message="Установлен" if act("equip_module",[selected_module,slot]) else "Этот модуль уже установлен"
   if Rect2(370+slot*450,710,410,50).has_point(point):act("remove_module",[slot])
 elif shop_tab==4:
  for i in range(6):
   var id=GUEST_IDS[i];var rect=regular_rect(i)
   if Rect2(rect.position+Vector2(12,100),Vector2(270,40)).has_point(point):shop_message="Угощение оплачено на следующий визит" if act("reserve_gift",[id]) else "Уже оплачено или недостаточно монет"
   if Rect2(rect.position+Vector2(12,145),Vector2(270,40)).has_point(point):shop_message="Награда получена" if act("claim_goal",[id,int(e.claimed[id])]) else "Личная цель ещё не выполнена"
 elif shop_tab==5:
  if Rect2(560,570,480,70).has_point(point):shop_message="Лига повышена" if act("promote_league",[int(e.league)]) else "Нужно больше известности или достигнута верхняя лига"
func draw_button(rect: Rect2,label: String,active=true) -> void:
 var size=25
 while size>14 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-32:size-=1
 draw_style_box(panel(Color("426951") if active else Color("2b353d")),rect)
 text_at(rect.position+Vector2(16,rect.size.y*.5+size*.35),label,size,Color("efdec0") if active else Color("a9a7a2"))
func tab_rect(i: int) -> Rect2:
 return [Rect2(133,143,430,112), Rect2(570,143,489,112), Rect2(1064,143,419,112)][i % 3]
func offer_rect(i: int) -> Rect2:
 if shop_tab>=3:return Rect2(100+i*490,330,450,230)
 return Rect2(140+i*452,322,425,435)
func gear_rect(i: int) -> Rect2:return Rect2(131+i*349,309,327,453)
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
 if screen=="intro":
  draw_entry()
  return
 draw_cafe()
 draw_charcoal_header()
 if screen=="fold":
  var distance=1600.0*smoothstep(0,FOLD_SECONDS,fold_elapsed)
  draw_set_transform(Vector2(-distance,0))
  draw_between()
  draw_set_transform(Vector2.ZERO)
  return
 if screen=="between":draw_between()
 elif screen=="progress":draw_progress()
 elif screen=="menu":
  draw_rect(Rect2(0,100,1600,800),Color(.025,.035,.045,.85));text_at(Vector2(675,310),"ПАУЗА",48)
  draw_button(MENU_RESUME,"Продолжить",repository.ready);draw_button(MENU_SOUND,"Звук выключен" if audio.muted else "Звук включён",repository.ready);draw_button(MENU_PROGRESS,"Прогресс и обучение",repository.ready);draw_button(MENU_REPORT,"Скопировать отчёт")
  if can_discard_cup():draw_button(MENU_DISCARD,"Вылить содержимое стакана")
  if not repository.ready:wrapped(Vector2(350,220),"Не удалось загрузить прогресс. Он не перезаписан. Перезапусти игру для повторной попытки.",900,26)
 else:draw_play()
 if repository.error!="":text_at(Vector2(35,882),"Не удалось сохранить действие. Прогресс не перезаписан.",20,Color("ee9a86"))
func draw_entry() -> void:
 var progress=smoothstep(0.35,2.6,intro_elapsed)
 var opening=smoothstep(0.0,1.0,intro_elapsed)
 var zoom=lerpf(1.48,1.0,progress)
 var offset=Vector2(-640, -210)*(1.0-progress)
 draw_texture_rect(CAFE,Rect2(offset,Vector2(1600,900)*zoom),false)
 draw_rect(Rect2(0,0,1600,900),Color(.015,.014,.02,lerpf(.95,.0,progress)))
 draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(1600*(1-opening),0),
  Vector2(1430*(1-opening),900),Vector2(0,900)]),Color("17151b"))
 text_at(Vector2(586,824),"Коснись, чтобы войти",26)

func draw_charcoal_header() -> void:
 draw_circle(Vector2(46,20),10,Color("d9c8ac"),false,2,true)
 draw_arc(Vector2(50,20),10,0,PI*.5,8,Color("d9c8ac"),2,true)
 text_at(Vector2(75,34),"Путь баристы",29)
 draw_circle(WALLET_COIN,10,Color("d9c8ac"),false,2,true)
 var shown=display_balance() if screen in ["between","fold"] else collection_balance()
 text_at(Vector2(437,34),str(shown),29)
 if screen in ["between","fold"] and not purchase_animation.is_empty():
  text_at(Vector2(516,34-6*purchase_progress()),"−"+str(purchase_animation.amount),19,Color(Color("f6bc8c"),1.0-purchase_progress()))
 var day: int = game.data.get("shift",{}).get("day_number",1)
 text_at(Vector2(577,34),"День "+str(day),27)
 var minutes: int = game.clock_minutes()
 text_at(Vector2(731,34),"%02d:%02d"%[minutes/60,minutes%60],26)
 if day>=6 and screen in ["between","fold"] and game.data.shift.phase=="PREPARING":
  var rush_minute: int=480+roundi(game.CareerShift.rush_start(day)*1.8)
  var market_text="Пик в %02d:%02d   ·   Покупки +%d%%   ·   Кофе +%d%%"%[rush_minute/60,rush_minute%60,5*game.Career.market_step(day),game.Career.sale_percent(day)]
  text_at(Vector2(858,32),market_text,16,Color("f6bc8c"))
 elif game.data.shift.get("market_rules",0)==1 and game.data.shift.phase=="RUNNING" and game.Career.in_rush(day,game.data.clock-game.data.shift.started_at):
  text_at(Vector2(897,34),"ЧАС ПИК",23,Color("f6bc8c"))
 if screen=="between" and game.data.shift.phase=="PREPARING":
  text_at(EXTRA_BUTTON.position+Vector2(12,32),"‹ Лист смены" if shop_tab>=3 else "Карьера ›",20)
 for i in range(3):
  draw_line(Vector2(1535,11+i*11),Vector2(1570,11+i*11),Color("eddfc8"),3,true)

func can_discard_cup() -> bool:
 return game.can_prepare() and not game.cup.is_empty() and not game.cup.carrying

func operation_color(station: int) -> Color:
 var extra: int=game.cup.excess(station)
 if extra==0:return PERFECT_COLOR
 if extra<0:return STATION_COLORS[station]
 if extra>=10:return OVERTAP_COLOR
 var amber=Color("f5c348")
 if extra<=4:return PERFECT_COLOR.lerp(amber,smoothstep(0.0,4.0,extra))
 return amber.lerp(OVERTAP_COLOR,smoothstep(4.0,10.0,extra))
func content_sprite(contents: String) -> String:return contents if contents in RECIPE_NAMES else "cappuccino"
func content_name(contents: String) -> String:return RECIPE_NAMES.get(contents,{"grounds":"Помол","milk":"Молоко","milk_grounds":"Молоко и помол","coffee_milk":"Кофе с молоком","empty":"Пусто"}.get(contents,contents))
func current_cup_label() -> String:return content_name(game.cup.contents())
func visit_speech(visit: Dictionary) -> String:
 var actor=rigs.get(visit.id)
 if actor==null or actor.phase not in ["idle","wait_leave"]:return ""
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
 var words=line.split(" ")
 for word in words:
  while size>12 and font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-16:size-=1
 var current="";var y=rect.position.y+size+9
 for word in words:
  if font.get_string_size(current+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-16:
   text_at(Vector2(rect.position.x+8,y),current,size,Color("302628"));current="";y+=size+5
  current+=word+" "
 text_at(Vector2(rect.position.x+8,y),current,size,Color("302628"))
func draw_play():
 if repository.legacy:super.draw_play();return
 if game.cup.milk_doses>=0:draw_milk_carton()
 for i in range(3):
  var color: Color=bar_colors[i]
  var bar: Rect2 = STATION_BARS[i]
  draw_rect(bar.grow(2),Color("111116"))
  draw_rect(bar,Color(color,0.34))
  draw_rect(bar,Color(color,0.48),false,1,true)
  if bar_progress[i]>0:
   var filled=Rect2(bar.position,Vector2(bar.size.x*bar_progress[i],bar.size.y))
   draw_rect(filled.grow(3),Color(color,0.25))
   draw_rect(filled,color)
 for visit in game.data.visits:
  var line=visit_speech(visit)
  if line.is_empty():continue
  var slot=int(slots[visit.id])
  var body: Rect2 = Layout.BODIES[slot]
  var face: Vector2 = rigs[visit.id].position+Vector2(body.size.x*.08,-body.size.y*.37)
  draw_bubble(Layout.bubble(slot),line,face,17)
 for payment in game.data.payments:
  if payment.state!="PENDING" or not slots.has(payment.visit_id):continue
  var center=visit_coin_rect(payment.visit_id).get_center()
  draw_coin(center,int(payment.amount),int(payment.tip),1.0,true)
 draw_coin_flights()
 if not game.cup.is_empty():
  if dragging:draw_pov_sleeve(cup_position)
  draw_cup(cup_position)
  if dragging:draw_texture(CUP_GRIP,cup_position+Vector2(-50,-99))
  else:text_at(V2_CUP_HOME+Vector2(-75,45),current_cup_label(),18)
 if game.data.clock<speech_until:draw_bubble(Rect2(930,288,360,80),speech_text,Vector2(1110,388),20)
 if repository.training:draw_button(Rect2(1100,800,460,65),"Закончить обучение")
 if screen=="lesson":wrapped(Vector2(30,225),lesson_hint(),600,21)
func draw_coin(center: Vector2,amount: int,tip: int,scale: float,on_counter: bool) -> void:
 var strength=float(tip)/(float(tip)+16.0)
 var pulse=0.5+0.5*sin(visual_clock*5.0+center.x*.012)
 var breathing=scale*(1.0+strength*pulse*.30)
 draw_set_transform(center,0.0,Vector2(1.0,.64)*breathing)
 if on_counter:draw_circle(Vector2(0,6),35,Color("18100cb0"),true,-1,true)
 if tip>0:
  for ring in range(4,0,-1):
   draw_circle(Vector2.ZERO,33+ring*2.8,Color(1.0,.76,.28,strength*(.14+.18*pulse)),true,-1,true)
 draw_circle(Vector2(0,4),33,Color("65401f"),true,-1,true)
 draw_circle(Vector2.ZERO,33,Color("c88f40").lerp(Color("fff2a2"),strength*(.35+.45*pulse)),true,-1,true)
 draw_arc(Vector2.ZERO,29,0,TAU,48,Color("f6d28c"),2.5,true)
 draw_arc(Vector2.ZERO,25,0,TAU,40,Color("91602e"),1.5,true)
 draw_set_transform(Vector2.ZERO)
 var label=str(amount)
 var size=maxi(10,roundi(27*breathing))
 var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 text_at(center+Vector2(-width/2,size*.33),label,size,Color("30211b"))

func draw_coin_flights() -> void:
 var total=0
 var arrived=1.0
 for flight in coin_flights:
  var elapsed: float=flight.elapsed
  if elapsed<COIN_TRAVEL:
   var t=elapsed/COIN_TRAVEL
   var center: Vector2=flight.source.lerp(WALLET_COIN,smoothstep(0.0,1.0,t))
   center.y-=sin(PI*t)*54
   draw_coin(center,flight.amount,flight.tip,lerpf(1.0,.28,t),false)
  else:
   total+=int(flight.amount)
   arrived=minf(arrived,(elapsed-COIN_TRAVEL)/(COIN_ANIMATION-COIN_TRAVEL))
 if total>0:
  text_at(WALLET_COIN+Vector2(13,51-13*arrived),"+"+str(total),24,Color(1.0,.83,.45,1.0-arrived))

func draw_between():
 if game.data.shift.phase=="PREPARING" and shop_tab<3:
  Charcoal.draw_sheet(self)
  return
 draw_rect(Rect2(20,115,1560,755),Color("111d27f5"));var shift=game.data.shift
 if shift.phase=="SUMMARY":
  text_at(Vector2(470,310),"Смена завершена",44)
  text_at(Vector2(470,380),"Выдано: "+str(shift.stats.served)+" · Хороших: "+str(shift.stats.good),28)
  text_at(Vector2(470,435),"Собрано: "+str(shift.stats.earned)+" монет",30,Color("ebbc76"))
  text_at(Vector2(470,485),"Ушло без кофе: "+str(shift.stats.left),25)
  if shift.stats.get("refused",0)>0:text_at(Vector2(470,532),"Отказались платить: "+str(shift.stats.refused),25)
  draw_button(NEXT_BUTTON,"Следующий день");return
 var C=game.Career;var e=game.data.economy
 for i in range(3):draw_button(tab_rect(i+3),EXTRA_TABS[i],shop_tab==i+3)
 if shop_tab==3:
  for i in range(3):
   var id=C.MODULES.keys()[i];var item=C.MODULES[id];var rect=offer_rect(i);draw_style_box(panel(Color("20323d")),rect)
   text_at(rect.position+Vector2(20,40),item.name,26);wrapped(rect.position+Vector2(20,85),item.description,405,22)
   text_at(rect.position+Vector2(20,205),"Выбрать" if id in e.owned_modules else str(C.purchase_price(game.data,int(item.price)))+" монет",24,Color("ebbc76"))
  for slot in range(2):
   var id=e.equipped_modules[slot];draw_button(Rect2(370+slot*450,630,410,65),"Слот "+str(slot+1)+": "+("Пусто" if id=="" else C.MODULES[id].name))
   draw_button(Rect2(370+slot*450,710,410,50),"Снять бесплатно",id!="")
 elif shop_tab==4:
  for i in range(6):
   var id=GUEST_IDS[i];var rect=regular_rect(i);draw_style_box(panel(Color("20323d")),rect)
   text_at(rect.position+Vector2(12,28),"Постоянник "+str(i+1)+" · "+RECIPE_NAMES[game.data.profiles[id].favorite],19)
   text_at(rect.position+Vector2(12,58),"Цель "+str(e.goals[id])+"/"+str(3 if e.claimed[id]==0 else 6)+" → "+str(C.GOAL_REWARDS[mini(1,int(e.claimed[id]))])+" монет",18)
   text_at(rect.position+Vector2(12,86),"Скидка на приборы 5/10%" if i==0 else "Друзья приходят чаще" if i==1 else "Награда за любимый кофе",18)
   draw_button(Rect2(rect.position+Vector2(12,100),Vector2(270,40)),"Угощение оплачено" if e.gifts[id] else "След. визит · "+str(C.purchase_price(game.data,int(game.PRICES[game.data.profiles[id].favorite]))))
   draw_button(Rect2(rect.position+Vector2(12,145),Vector2(270,40)),"Забрать награду" if e.claimed[id]<2 else "Цели выполнены",e.claimed[id]<2)
  text_at(Vector2(70,740),"Угощение оплачивает следующий визит. Доверие меняется только от напитка.",21)
 else:
  text_at(Vector2(500,380),"Известность: "+str(e.fame)+" · Лига "+str(int(e.league)+1),36)
  wrapped(Vector2(500,440),"Новая лига повышает поток и цены. Переход только по твоему выбору. Порог следующей: "+(str(C.LEAGUE_FAME[int(e.league)+1]) if e.league<2 else "достигнута верхняя лига"),650,24)
  draw_button(Rect2(560,570,480,70),"Повысить лигу",e.league<2)
 if shop_message!="":wrapped(Vector2(60,740 if shop_tab!=3 else 610),shop_message,1400,22)
 draw_button(START_BUTTON,"Начать смену")
func draw_progress():
 if repository.legacy:super.draw_progress();return
 draw_rect(Rect2(20,110,1560,770),Color("111d27ef"));draw_button(BACK_BUTTON,"‹ Назад в меню")
 text_at(Vector2(420,230),"Прогресс карьеры",42);text_at(Vector2(420,300),"День "+str(game.data.shift.day_number)+" · "+str(game.data.money)+" монет",30)
 text_at(Vector2(420,360),"Известность "+str(game.data.economy.fame)+" · Лига "+str(int(game.data.economy.league)+1),28)
 wrapped(Vector2(420,440),"Приборы, модули и угощения доступны между сменами. Обучение не меняет деньги, историю гостей и поток основной игры.",900,26)
 draw_button(LESSON_BUTTON,"Потренироваться")
func start_lesson():
 if repository.begin_lesson():
  coin_flights.clear()
  main_rigs=rigs;main_slots=slots;main_bars=bar_progress.duplicate()
  rigs={};slots={};game=repository.session;screen="lesson";paused=false;lesson_completed=false
  speech_until=-1;facepalm_until=-1;speech_last.clear()
  sync_guest(true);bar_progress=[0.0,0.0,0.0];update_audio()
func finish_lesson():
 coin_flights.clear()
 clear_rigs();repository.end_training();game=repository.session
 rigs=main_rigs;slots=main_slots;bar_progress=main_bars
 main_rigs={};main_slots={};main_bars=[]
 speech_until=-1;facepalm_until=-1;speech_last.clear()
 screen="menu";paused=true;cancel_drag(true);update_audio()
func clear_rigs():
 for rig in rigs.values():rig.free()
 rigs.clear();slots.clear()
func draw_milk_carton() -> void:
 var art=Rect2(CARTON_RECT.position+Vector2(0,8),CARTON_RECT.size)
 draw_texture_rect(CARTON,art,false)
 for i in range(2):
  var front=art.position+CARTON_RECT.size*Vector2((16+i*14)/64.0,33.0/86.0)
  var size=CARTON_RECT.size*Vector2(12.0/64.0,16.0/86.0)
  draw_texture_rect(DROP,Rect2(front,size),false,Color("ffe6a9") if i<game.cup.milk_doses else Color("768780"))

func lesson_hint() -> String:
 if repository.legacy:return super.lesson_hint()
 return "Эспрессо — помол и варка. Для капучино добавь одну порцию молока, для латте две. Коробка сверху, прогрев снизу. Передай стакан гостю и собери монеты." if not lesson_completed else "Заказ пройден! Можно продолжить тренировку или закончить."
func draw_cafe():
 if repository==null:return
 if repository.legacy:super.draw_cafe();return
 draw_texture_rect(CAFE,Rect2(0,0,1600,900),false)
 if screen in ["progress","between","intro","fold"]:
  return
 for slot in range(Layout.COUNT-1,-1,-1):
  for id in rigs:
   if slots[id]!=slot:
    continue
   var actor=rigs[id]
   if actor.phase in ["wait_enter","gone"]:
    continue
   var body: Rect2=Layout.BODIES[slot]
   var zoom: float=actor.scale.x/actor.base_scale
   var offset: Vector2=actor.position-Layout.home(slot)
   var sway=Vector2(0,-absf(sin(actor.clock*8))*actor.walk*7)
   body=Rect2(body.get_center()+offset+sway-body.size*zoom/2,body.size*zoom)
   var turns: bool=actor.phase=="leave" or (actor.phase=="turn" and actor.facing>=0)
   if turns:body=Rect2(body.position+Vector2(body.size.x,0),Vector2(-body.size.x,body.size.y))
   var visit: Dictionary = game.find_visit(id)
   var identity: int = int(visit.customer_id.right(2))-1
   var texture: Texture2D = VISITORS[mini(identity,VISITORS.size()-1)]
   var modulate_guest = Color("c4b8ce") if identity>=VISITORS.size() else Color.WHITE
   draw_texture_rect(texture,body,false,modulate_guest)
 # The worktop is a foreground occluder during entrance and exit.
 var lip=PackedVector2Array([Vector2(0,725),Vector2(75,725),Vector2(670,474),Vector2(823,474),
  Vector2(805,504),Vector2(410,722),Vector2(1600,722),Vector2(1600,900),Vector2(0,900)])
 var uv=PackedVector2Array()
 for point in lip:uv.append(point/Vector2(1600,900))
 draw_polygon(lip,PackedColorArray([Color.WHITE]),uv,CAFE)

func draw_pov_sleeve(at: Vector2) -> void:
 var cuff=at+Vector2(42,1)
 var direction=(Vector2(755,930)-cuff).normalized()
 var start=cuff+direction*185
 var side=direction.orthogonal()
 var left=cuff+side*15
 var right=cuff-side*15
 var cloth=Color("383034")
 draw_polygon(PackedVector2Array([start+side*34,start-side*34,right,left]),
  PackedColorArray([Color(cloth,0),Color(cloth,0),cloth,cloth]))
 draw_line(left,right,Color("251e22"),4,true)
 draw_line(left+direction*10,right+direction*10,Color("665255"),2,true)

func draw_cup(at: Vector2):
 if repository.legacy:super.draw_cup(at);return
 draw_set_transform(at);draw_texture_rect(CHARCOAL_CUP,Rect2(-46,-129,92,135),false)
 var heat=game.cup.temperature(game.data.clock)
 if heat>0:
  for i in range(3):
   var points=PackedVector2Array()
   for j in range(14):points.append(Vector2((i-1)*12+sin(j*.4+visual_clock*2+i)*5,-55-j*3-fmod(visual_clock*22+i*17,60)*.35))
   draw_polyline(points,Color(.95,.91,.82,heat*.4),2,true)
 draw_set_transform(Vector2.ZERO)

func record_drop_trace(cup_id: int,delivered: bool):
 if not OS.is_debug_build():return
 var targets=[]
 for visit in game.data.visits:
  var rect=visit_drop_rect(visit.id);var actor=rigs.get(visit.id)
  targets.append({"id":visit.id,"state":visit.state,"slot":slots.get(visit.id,-1),"phase":actor.phase if actor!=null else "missing","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
 var file=FileAccess.open(save_directory+"/v2-last-drop.json",FileAccess.WRITE)
 if file!=null:
  file.store_string(JSON.stringify({"cup_id":cup_id,"clock":game.data.clock,"at":[cup_position.x,cup_position.y],"screen":screen,"paused":paused,"ready":repository.ready,"error":repository.error,"current_cup_id":game.data.cup_id,"carrying":game.cup.carrying,"delivered":delivered,"targets":targets}));file.close()
