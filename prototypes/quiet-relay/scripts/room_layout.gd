extends RefCounted

# World-space floors; the open stairwells are bridged by drop-through landings.
const WIDTH: float = 1600.0
const FLOOR_STEP: float = 900.0
const LINKS: Array = [Vector2i(1,2), Vector2i(2,3), Vector2i(3,4), Vector2i(4,5), Vector2i(5,6)]

static func definitions() -> Array:
	return [
		{"id":1, "cell":Vector2i(0,2), "floor":560.0, "title":"SAFE PRACTICE", "color":Color("8cbdae")},
		{"id":2, "cell":Vector2i(1,2), "floor":560.0, "title":"LOWER GALLERY", "color":Color("c7b37d")},
		{"id":3, "cell":Vector2i(1,1), "floor":-340.0, "title":"ARRIVAL BALCONY", "color":Color("81b5d0")},
		{"id":4, "cell":Vector2i(0,1), "floor":-340.0, "title":"SHELTERED GALLERY", "color":Color("a9a1cf")},
		{"id":5, "cell":Vector2i(0,0), "floor":-1240.0, "title":"WARDEN APPROACH", "color":Color("c69b86")},
		{"id":6, "cell":Vector2i(1,0), "floor":-1240.0, "title":"OPEN SANCTUM", "color":Color("a4c5bb")},
	]

static func stairs(x: float, floor_y: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for step in range(1,9):
		result.append(Rect2(x + (160.0 if step % 2 == 0 else 0.0), floor_y - step*100.0, 240, 18))
	return result
