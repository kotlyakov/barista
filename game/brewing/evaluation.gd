extends RefCounted
const Cup=preload("res://brewing/cup.gd")

# Returns an empty dictionary for invalid input. No caller data is modified.
static func evaluate(cup: Dictionary,wish_recipe: String,waited: float,patience: float,now: float) -> Dictionary:
 if not Cup.valid(cup) or not Cup.TARGETS.has(wish_recipe): return {}
 if not Cup.finite_number(waited,0) or not Cup.finite_number(patience,0) or patience<=0 or not Cup.finite_number(now,0) or now<cup.last_tap: return {}
 var b=Cup.restore(cup)
 var values=b.qualities()
 var g=float(values[0])
 var brew=float(values[1])
 var m=float(values[2])
 var with_milk=b.recipe!="espresso" or b.taps[2]>0
 var q=0.25*g+0.45*brew
 var d=minf(g,brew)
 if with_milk:
  q+=0.30*m
  d=minf(d,m)
 else: q/=0.70
 var contents=b.contents()
 var r=0.0
 if contents in ["espresso","cappuccino","latte"]: r=1.0 if contents==wish_recipe else 0.5
 elif contents=="coffee_milk": r=0.5
 var t=b.temperature(now)
 var w=clampf(1-waited/patience,0,1)
 var factors=(0.20+0.80*r)*(0.25+0.75*t)*(0.40+0.60*d)
 var c=clampf(q*factors,0,1)
 var j=clampf(100*(0.85*q+0.15*w)*factors,0,100)
 var defects=b.defects()
 if not with_milk: defects.erase("milk")
 return {"g":g,"b":brew,"m":m,"Q":q,"d":d,"T":t,"W":w,"R":r,"J":j,"C":c,"contents":contents,"defects":defects}
