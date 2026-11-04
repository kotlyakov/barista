extends Node2D
# Presentation only. The repository remains the authority for orders and money.
const EMOTIONS=["neutral","happy","delighted","impatient","unhappy","angry","disappointed","surprised"]
var actor_id="beard"
var phase="gone"
var elapsed=0.0
var clock=0.0
var facing=-1.0
var emotion="neutral"
var previous_emotion="neutral"
var emotion_mix=1.0
var home=Vector2(1120,315)
var base_scale=1.04
var textures={}
var walk=0.0
var held_cup=false
var reaching=false
var cup_recipe="cappuccino"
func enter(id: String,immediate=false) -> void:
 actor_id=id
 if textures.get("id")!=id:
  textures={"id":id}
  var parts=["body"]
  if id=="barista": parts.append("body-reaching")
  if id!="barista": parts.append_array(["hips","leg0","leg1","cup-espresso","cup-cappuccino","cup-latte"])
  for face in EMOTIONS:
   parts.append("head-"+face)
   parts.append("head-"+face+"-blink")
  for part in parts: textures[part]=load("res://content/art/cafe/"+id+"-"+part+".svg")
 home=Vector2(299,259) if id=="barista" else Vector2(1120,315)
 base_scale=1.08 if id=="barista" else 1.04 if id=="beard" else .87
 facing=1 if id=="barista" else -1
 phase="idle" if immediate or id=="barista" else "enter"
 elapsed=0
 position=home if phase=="idle" else Vector2(1550,180)
 scale=Vector2.ONE*base_scale*(1 if phase=="idle" else .38)
 held_cup=false
func set_emotion(value: String) -> void:
 if value=="annoyed": value="unhappy"
 if not value in EMOTIONS: value="neutral"
 if value==emotion: return
 previous_emotion=emotion
 emotion=value
 emotion_mix=0
func depart() -> void:
 if phase in ["turn","leave","gone"]: return
 phase="turn"
 elapsed=0
 # A guest can leave before reaching the counter, e.g. restored short patience.
 home=position
func step(delta: float) -> void:
 clock+=delta
 emotion_mix=minf(1,emotion_mix+delta/0.7)
 elapsed+=delta
 walk=0
 if phase=="enter":
  var p=clampf(elapsed/2.4,0,1)
  var t=smoothstep(0,1,p)
  position=Vector2(1550,180).lerp(home,t)
  scale=Vector2.ONE*base_scale*lerpf(.38,1,t)
  walk=sin(p*PI)
  if p>=1: phase="idle";elapsed=0
 elif phase=="turn":
  facing=lerpf(-1,1,clampf(elapsed/.35,0,1))
  if elapsed>=.35: phase="leave";elapsed=0
 elif phase=="leave":
  var p=clampf(elapsed/2.1,0,1)
  var t=smoothstep(0,1,p)
  position=home.lerp(Vector2(1710,165),t)
  scale=Vector2.ONE*base_scale*lerpf(1,.38,t)
  walk=sin(p*PI)
  if p>=1: phase="gone"
func layer(canvas: CanvasItem,part: String,offset=Vector2.ZERO,angle=0.0,pivot=Vector2.ZERO,alpha=1.0) -> void:
 var mirror=1.0 if actor_id=="barista" else -facing
 var s=Vector2(scale.x*mirror,scale.y)
 # Transform both translation and joint pivot; textures retain exact SVG coordinates.
 var sway=Vector2(sin(clock*.73)*1.2,-absf(sin(clock*5.6))*walk*.8)
 var origin=position+(offset+sway+pivot-pivot.rotated(angle))*s
 canvas.draw_set_transform(origin,angle,s)
 canvas.draw_texture(textures[part],Vector2(-200,-130),Color(1,1,1,alpha))
func draw_on(canvas: CanvasItem) -> void:
 if phase=="gone": return
 if actor_id!="barista":
  layer(canvas,"hips")
  var hip=335 if actor_id=="beard" else 410
  for i in range(2):
   var stride=sin(clock*5.6+i*PI)*walk
   layer(canvas,"leg"+str(i),Vector2(0,-maxf(0,stride)*6),stride*.19,Vector2(-30 if i==0 else 80,hip))
 layer(canvas,"body-reaching" if actor_id=="barista" and reaching else "body",Vector2(0,sin(clock*1.05)*.7*(1-walk)))
 var blink=fmod(clock,4.7)>.0 and fmod(clock,4.7)<.14
 var suffix="-blink" if blink else ""
 if emotion_mix<1: layer(canvas,"head-"+previous_emotion+suffix,Vector2.ZERO,0,Vector2.ZERO,1-emotion_mix)
 layer(canvas,"head-"+emotion+suffix,Vector2.ZERO,0,Vector2.ZERO,emotion_mix)
 if held_cup and actor_id!="barista": layer(canvas,"cup-"+cup_recipe)
 canvas.draw_set_transform(Vector2.ZERO)
