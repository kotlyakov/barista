extends RefCounted
var active = -2
func cancel() -> void:
 active=-2
func route(event: InputEvent, blocked=false) -> Dictionary:
 if blocked:
  cancel()
  return {}
 if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION: return {}
 var id=-1
 var press=false
 var release=false
 if event is InputEventScreenTouch:
  id=event.index
  press=event.pressed
  release=not event.pressed
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  press=event.pressed
  release=not event.pressed
 elif event is InputEventScreenDrag:
  if event.index==active: return {"action":"move","position":event.position}
  return {}
 elif event is InputEventMouseMotion:
  if active==-1: return {"action":"move","position":event.position}
  return {}
 else: return {}
 if press and active==-2:
  active=id
  return {"action":"press","position":event.position}
 if release and active==id:
  active=-2
  return {"action":"release","position":event.position}
 return {}
