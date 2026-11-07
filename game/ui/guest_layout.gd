extends RefCounted

const COUNT = 5
const BODIES = [
 Rect2(10, 258, 313, 480), Rect2(300, 168, 162, 428),
 Rect2(492, 149, 182, 390), Rect2(692, 134, 188, 367),
 Rect2(1357, 107, 187, 403)
]
const COLUMNS = [Rect2(30, 0, 250, 0), Rect2(301, 0, 177, 0), Rect2(493, 0, 184, 0),
 Rect2(697, 0, 190, 0), Rect2(1346, 0, 214, 0)]
const TOPS = [190, 105, 100, 100, 100]
const TARGET_TOPS = [290, 176, 170, 170, 180]
const TARGET_BOTTOMS = [685, 513, 482, 455, 455]

static func home(index: int) -> Vector2:
 return BODIES[index].get_center()

static func drop(index: int) -> Rect2:
 var col: Rect2 = COLUMNS[index]
 return Rect2(col.position.x, TARGET_TOPS[index], col.size.x, TARGET_BOTTOMS[index] - TARGET_TOPS[index])

static func bubble(index: int) -> Rect2:
 var col: Rect2 = COLUMNS[index]
 return Rect2(col.position.x, TOPS[index], col.size.x, TARGET_TOPS[index] - TOPS[index] - 5)

static func coins(index: int) -> Rect2:
 var col: Rect2 = COLUMNS[index]
 return Rect2(col.position.x + (col.size.x - 72) / 2, TARGET_BOTTOMS[index] + 2, 72, 58)
