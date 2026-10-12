extends Node

const FRAME_BUDGET_USEC := 2000
const Policy = preload("res://world_stream_policy.gd")
var host: Node3D
var focus := Vector2.ZERO
var predicted := Vector2.ZERO
var clock := 0.0
var previous := Vector2.ZERO
var frame_id := -1
var spent_usec := 0
var providers: Array[Node] = []
var cycles := 0
var visuals: Dictionary = {}

func initialize(game: Node3D) -> void:
	host = game
	focus = Vector2(host.player.position.x,host.player.position.z)
	predicted = focus
	previous = focus

func register_provider(provider: Node) -> void:
	if not providers.has(provider):
		providers.append(provider)
	provider.set_meta("streaming_managed",true)

func request_pack(id: String, position: Vector2, foreground: bool = false) -> bool:
	var priority := minf(position.distance_to(focus),position.distance_to(predicted))
	return await AssetPacks.ensure_pack(id,foreground,priority)

func checkpoint(elapsed_usec: int) -> void:
	var current := Engine.get_process_frames()
	if current!=frame_id:
		frame_id = current
		spent_usec = 0
	spent_usec += elapsed_usec
	if spent_usec>=FRAME_BUDGET_USEC:
		await get_tree().process_frame

func in_cell_interest(position: Vector2) -> bool:
	return should_load(Policy.cell_bounds(preload("res://world_lod.gd").cell_index(position)))

func in_near_interest(position: Vector2) -> bool:
	var bounds := Policy.cell_bounds(preload("res://world_lod.gd").cell_index(position))
	return Policy.state(bounds,focus)=="near" or Policy.state(bounds,predicted)=="near"

func should_load(bounds: Rect2) -> bool:
	return Policy.should_load(bounds,focus,predicted)

func should_retain(bounds: Rect2) -> bool:
	return Policy.should_retain(bounds,focus,predicted)

func is_active(bounds: Rect2) -> bool:
	return Policy.state(bounds,focus)!="off"

func is_detailed(bounds: Rect2) -> bool:
	return Policy.state(bounds,focus)=="near"

func register_visuals(root: Node) -> void:
	if root is GeometryInstance3D:
		var label := str(root.get_meta("r3f_source_name",root.name))
		if not label.begins_with("terrain-"):
			root.visibility_range_begin = 0.0
			root.visibility_range_end = 0.0
			visuals[root.get_instance_id()] = {"node":root,"bounds":root.get_aabb()}
	for child in root.get_children():
		register_visuals(child)

func update_visuals() -> void:
	for id in visuals.keys():
		var entry: Dictionary = visuals[id]
		if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion() or not entry.node.is_inside_tree():
			visuals.erase(id)
			continue
		var bounds: AABB = entry.node.global_transform*entry.bounds
		entry.node.visible = is_active(Policy.horizontal_bounds(bounds))

func unregister_visuals(root: Node) -> void:
	visuals.erase(root.get_instance_id())
	for child in root.get_children():
		unregister_visuals(child)

func _process(delta: float) -> void:
	if not is_instance_valid(host) or host.picking_profile or host.loading_room:
		return
	focus = Vector2(host.player.position.x,host.player.position.z)
	var velocity := (focus-previous)/maxf(delta,0.00001)
	velocity = velocity.limit_length(Policy.MAX_SPEED)
	predicted = focus+velocity*Policy.PREFETCH_SECONDS
	previous = focus
	clock += delta
	if clock<0.1:
		return
	clock = 0
	cycles += 1
	for provider in providers.duplicate():
		if not is_instance_valid(provider):
			providers.erase(provider)
			continue
		provider.stream_update()
	update_visuals()

func info() -> Dictionary:
	return {"focus":[focus.x,focus.y],"predicted":[predicted.x,predicted.y],"providers":providers.size(),"cycles":cycles,"budgetUsec":FRAME_BUDGET_USEC,"rule":"player-radius-v1","detailRadius":Policy.DETAIL_RADIUS,"activeRadius":Policy.ACTIVE_RADIUS,"loadRadius":Policy.LOAD_RADIUS,"retainRadius":Policy.RETAIN_RADIUS}
