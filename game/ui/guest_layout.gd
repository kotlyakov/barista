extends RefCounted
const COUNT=5
static func home(index: int) -> Vector2:return Vector2(1009+126*index,380)
static func drop(index: int) -> Rect2:return Rect2(950+126*index,410,118,120)
static func bubble(index: int) -> Rect2:return Rect2(950+126*index,180,118,80)
static func coins(index: int) -> Rect2:return Rect2(963+126*index,545,92,70)
