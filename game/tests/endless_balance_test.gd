extends SceneTree
const Service=preload("res://orders/service.gd")

func _init() -> void:
 var s=Service.new()
 s.enable_career();s.enable_development()
 s.data.shift=Service.CareerShift.make(31,"calm",1)
 for id in ["grind","brew","milk","ads"]:s.data.upgrades[id]=10
 s.configure_cup()
 if s.Career.equipment_price(s.data,0)!=500 or s.Career.purchase_price(s.data,650)!=813:
  push_error("Buy price uses the capped late coefficient");quit(1);return
 s.data.money=813
 if not s.buy_passive("wish",0) or s.data.money!=0:
  push_error("Displayed passive price must match actual debit");quit(1);return
 s.start_shift(31)
 if not s.data.shift.has("market_rules"):
  push_error("Late career needs a versioned market and rush schedule");quit(1);return
 var rush: float=s.CareerShift.rush_start(31)
 var quiet: float=s.Career.arrival_interval(s.data,rush+72)
 var peak: float=s.Career.arrival_interval(s.data,rush+12)
 if quiet<=peak*1.5:
  push_error("Rush and quiet hours must remain distinct at full upgrades");quit(1);return
 if s.Career.base_price(s.data,"latte",false)!=103:
  push_error("Late sale modifier missing");quit(1);return
 var stacked=Service.new()
 stacked.enable_career();stacked.enable_development()
 stacked.data.money=20000
 stacked.data.economy.offers=["warmth","aroma","change"]
 for level in range(5):stacked.buy_passive("warmth",level)
 stacked.buy_perk("warmth",1)
 stacked.buy_module("heat");stacked.equip_module("heat",0)
 if not is_equal_approx(stacked.cup.cooling_seconds,4.5) or Service.restore(stacked.snapshot())==null:
  push_error("Maximum legal warmth must persist");quit(1);return
 print("PASS: market, higher sale price, distinct late-game waves and legal warmth stacking")
 quit()
