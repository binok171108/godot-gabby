extends RefCounted

const Policy = preload("res://world_stream_policy.gd")
const CELL_SIZE := Policy.CELL_SIZE
var terrain: Dictionary = {}

static func cell_index(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

static func cell_state(point: Vector2, focus: Vector2) -> String:
	return Policy.state(Policy.cell_bounds(cell_index(point)),focus)

static func classify_point(point: Vector2, focus: Vector2, skyline: bool) -> String:
	if Policy.state(Rect2(point,Vector2.ZERO),focus)=="near":
		return "shadow"
	return "rest" if Policy.state(Rect2(point,Vector2.ZERO),focus)=="lod" else "off"

static func terrain_level(distance: float) -> int:
	return 0 if distance<=Policy.DETAIL_RADIUS else (1 if distance<=Policy.ACTIVE_RADIUS else 2)

func clear() -> void:
	terrain.clear()

func register_terrain(mesh: MeshInstance3D, source_name: String) -> void:
	if not source_name.begins_with("terrain-") or not source_name.contains("-lod"):
		return
	var parts := source_name.rsplit("-lod", false, 1)
	var level := int(parts[1])
	if not terrain.has(parts[0]):
		terrain[parts[0]] = {}
	terrain[parts[0]][level] = mesh

func update(focus_position: Vector3) -> void:
	for levels in terrain.values():
		if levels.is_empty():
			continue
		var first: MeshInstance3D = levels.values()[0]
		if not is_instance_valid(first):
			continue
		var bounds: AABB = first.global_transform*first.get_aabb()
		var separation := Policy.distance(Policy.horizontal_bounds(bounds),Vector2(focus_position.x,focus_position.z))
		var chosen := terrain_level(separation)
		if not levels.has(chosen):
			chosen = levels.keys().max()
		for level in levels:
			var mesh: MeshInstance3D = levels[level]
			if mesh.visible != (level == chosen and separation<=Policy.ACTIVE_RADIUS):
				mesh.visible = level == chosen and separation<=Policy.ACTIVE_RADIUS

func unregister(mesh: MeshInstance3D) -> void:
	for key in terrain.keys():
		var levels: Dictionary = terrain[key]
		for level in levels.keys():
			if levels[level] == mesh:
				levels.erase(level)
		if levels.is_empty():
			terrain.erase(key)
