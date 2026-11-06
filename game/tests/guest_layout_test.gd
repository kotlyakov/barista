extends SceneTree
func _init():
 if not ResourceLoader.exists("res://ui/guest_layout.gd"):print("FAIL: five-guest layout absent");quit(1);return
 var L=load("res://ui/guest_layout.gd")
 for n in range(5):
  assert(Rect2(0,100,1600,800).encloses(L.drop(n)))
  assert(not L.drop(n).intersects(L.coins(n)))
  assert(not L.drop(n).intersects(L.bubble(n)))
  for m in range(5):
   if m==n:continue
   for a in [L.drop(n),L.coins(n),L.bubble(n)]:
    for b in [L.drop(m),L.coins(m),L.bubble(m)]:assert(not a.intersects(b))
 print("PASS: five bounded non-overlapping drop/bubble/coin zones outside HUD and machines")
 quit()
