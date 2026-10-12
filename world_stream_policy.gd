extends RefCounted

const CELL_SIZE := 60.0
const DETAIL_RADIUS := 24.0
const ACTIVE_RADIUS := 48.0
const MAX_SPEED := 8.0
const PREFETCH_SECONDS := 2.0
const LOAD_RADIUS := ACTIVE_RADIUS+MAX_SPEED*PREFETCH_SECONDS
const RETAIN_RADIUS := LOAD_RADIUS+MAX_SPEED*PREFETCH_SECONDS
const MOVE_THRESHOLD := 4.0

static func cell_bounds(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell)*CELL_SIZE,Vector2.ONE*CELL_SIZE)

static func distance(bounds: Rect2, focus: Vector2) -> float:
	return focus.distance_to(focus.clamp(bounds.position,bounds.end))

static func state(bounds: Rect2, focus: Vector2) -> String:
	var separation := distance(bounds,focus)
	return "near" if separation<=DETAIL_RADIUS else ("lod" if separation<=ACTIVE_RADIUS else "off")

static func should_load(bounds: Rect2, focus: Vector2, predicted: Vector2) -> bool:
	return minf(distance(bounds,focus),distance(bounds,predicted))<=LOAD_RADIUS

static func should_retain(bounds: Rect2, focus: Vector2, predicted: Vector2) -> bool:
	return minf(distance(bounds,focus),distance(bounds,predicted))<=RETAIN_RADIUS

static func horizontal_bounds(bounds: AABB) -> Rect2:
	return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
