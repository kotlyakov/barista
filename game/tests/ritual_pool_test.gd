extends SceneTree
const Service=preload("res://orders/service.gd")
const Career=preload("res://economy/career.gd")

func _init() -> void:
 if Career.PERKS.size()!=16:
  push_error("Expected 16 working rituals");quit(1);return
 var featured_count=0
 var control_count=0
 for seed_value in range(360):
  var game=Service.new(seed_value)
  game.enable_career()
  game.enable_development()
  game.data.shift.event_id="rain"
  Career.offers(game)
  var offers: Array=game.data.economy.offers
  if offers.size()!=3 or offers[0]==offers[1] or offers[0]==offers[2] or offers[1]==offers[2]:quit(1);return
  featured_count+=int("warmth" in offers)
  control_count+=int("change" in offers)
  var restored=Service.restore(JSON.parse_string(JSON.stringify(game.snapshot())))
  if restored==null or restored.data.economy.offers!=offers or restored.data.rng_state!=game.data.rng_state:quit(1);return
 if featured_count<=control_count or featured_count==360:
  push_error("Weather bias must favor warmth without guaranteeing it");quit(1);return
 print("PASS: 16 rituals, no duplicate offers, persisted RNG and probabilistic rain bias")
 quit()
