extends Node

signal entity_spawned(id: StringName, instance: Node3D)
signal entity_despawned(id: StringName)
signal resource_needed(scene_key: StringName)
signal spawn_failed(id: StringName, reason: String)

const CELL_SIZE: float = 64.0
const ACTIVE_RADIUS: float = 64.0
const FRAME_BUDGET_USEC: int = 2000
const MAX_SPAWNS_PER_FRAME: int = 1
const MAX_NODE_CHANGES_PER_FRAME: int = 4
const UPDATE_INTERVAL: float = 0.1

var entities: Dictionary[StringName, Dictionary] = {}
var scene_cache: Dictionary[StringName, PackedScene] = {}
var active_nodes: Dictionary[StringName, Node3D] = {}
var grid: Dictionary[Vector2i, Dictionary] = {}
var player: Node3D
var world_root: Node3D
var height_query: Callable
var _spawn_queue: Array[StringName] = []
var _despawn_queue: Array[StringName] = []
var _missing_resources: Dictionary[StringName, bool] = {}
var _clock: float = 0.0
var _dirty: bool = true
var _working: bool = false
var _generation: int = 0
var _max_extent: float = 0.0

func configure(focus: Node3D, parent: Node3D) -> void:
	if player != focus or world_root != parent:
		_generation += 1
		for id: StringName in active_nodes.keys():
			_despawn(id)
		_spawn_queue.clear()
		_despawn_queue.clear()
		_working = false
	player = focus
	world_root = parent
	_dirty = true

func bind_terrain(terrain: Node3D) -> bool:
	height_query = Callable()
	if not is_instance_valid(terrain):
		return false
	for property: Dictionary in terrain.get_property_list():
		if property.name not in ["data","storage"]:
			continue
		var data: Resource = terrain.get(property.name) as Resource
		if data != null and data.has_method("get_height"):
			height_query = Callable(data,"get_height")
			_dirty = true
			return true
	return false

func register_scene(key: StringName, scene: PackedScene) -> bool:
	if scene == null or not scene.can_instantiate():
		return false
	var root_type: StringName = scene.get_state().get_node_type(0)
	if root_type != &"Node3D" and not ClassDB.is_parent_class(root_type,&"Node3D"):
		return false
	scene_cache[key] = scene
	_missing_resources.erase(key)
	_dirty = true
	return true

func register_multimesh_scene(key: StringName, multimesh: MultiMesh, material: Material = null) -> bool:
	if multimesh == null or multimesh.mesh == null:
		return false
	var output: MultiMeshInstance3D = MultiMeshInstance3D.new()
	output.multimesh = multimesh
	output.material_override = material
	output.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	output.custom_aabb = multimesh.get_aabb().grow(0.15)
	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(output)
	output.free()
	return error == OK and register_scene(key,scene)

func register_entity(id: StringName, scene_key: StringName, position: Vector3, state: Dictionary = {}, snap_to_terrain: bool = true, extent: Vector2 = Vector2.ZERO) -> bool:
	if entities.has(id) or not position.is_finite() or not extent.is_finite() or extent.x<0 or extent.y<0:
		return false
	var cell: Vector2i = cell_at(position)
	entities[id] = {"scene_key":scene_key,"position":position,"state":state.duplicate(true),"snap_to_terrain":snap_to_terrain,"extent":extent,"cell":cell,"enabled":true}
	_add_to_grid(id,cell)
	_max_extent = maxf(_max_extent,maxf(extent.x,extent.y))
	_dirty = true
	return true

func move_entity(id: StringName, position: Vector3) -> bool:
	if not entities.has(id) or not position.is_finite():
		return false
	var entry: Dictionary = entities[id]
	if entry.snap_to_terrain:
		position = _terrain_position(id,position)
		if not position.is_finite():
			return false
	var new_cell: Vector2i = cell_at(position)
	var old_cell: Vector2i = entry.cell
	if new_cell != old_cell:
		_remove_from_grid(id,old_cell)
		_add_to_grid(id,new_cell)
		entry.cell = new_cell
	entry.position = position
	if active_nodes.has(id):
		var instance: Node3D = active_nodes[id]
		if is_instance_valid(instance):
			instance.global_position = position
	_dirty = true
	return true

func set_entity_state(id: StringName, key: StringName, value: Variant) -> bool:
	if not entities.has(id):
		return false
	var state: Dictionary = entities[id].state
	state[key] = value
	return true

func set_entity_enabled(id: StringName, enabled: bool) -> void:
	if entities.has(id):
		entities[id].enabled = enabled
		_dirty = true

func request_refresh() -> void:
	_dirty = true

func erase_entity(id: StringName) -> void:
	if not entities.has(id):
		return
	_despawn(id)
	_remove_from_grid(id,entities[id].cell)
	entities.erase(id)
	_dirty = true

func clear_world() -> void:
	_generation += 1
	for id: StringName in active_nodes.keys():
		_despawn(id)
	entities.clear()
	grid.clear()
	_spawn_queue.clear()
	_despawn_queue.clear()
	_missing_resources.clear()
	_max_extent = 0.0
	_working = false
	_dirty = true

func clear_resources() -> bool:
	if not entities.is_empty() or not active_nodes.is_empty():
		return false
	scene_cache.clear()
	return true

static func cell_at(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x/CELL_SIZE),floori(position.z/CELL_SIZE))

func is_required(id: StringName) -> bool:
	if not entities.has(id) or not is_instance_valid(player):
		return false
	var entry: Dictionary = entities[id]
	if not entry.enabled:
		return false
	var position: Vector3 = entry.position
	var extent: Vector2 = entry.extent
	var focus: Vector2 = Vector2(player.global_position.x,player.global_position.z)
	var center: Vector2 = Vector2(position.x,position.z)
	var closest: Vector2 = focus.clamp(center-extent,center+extent)
	return focus.distance_squared_to(closest)<=ACTIVE_RADIUS*ACTIVE_RADIUS

func _add_to_grid(id: StringName, cell: Vector2i) -> void:
	if not grid.has(cell):
		grid[cell] = {}
	grid[cell][id] = true

func _remove_from_grid(id: StringName, cell: Vector2i) -> void:
	if not grid.has(cell):
		return
	grid[cell].erase(id)
	if grid[cell].is_empty():
		grid.erase(cell)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_root) or not player.is_inside_tree() or not world_root.is_inside_tree():
		return
	_clock += delta
	if _working or (_clock<UPDATE_INTERVAL and not _dirty):
		return
	_clock = 0.0
	_dirty = false
	_work()

func _work() -> void:
	_working = true
	var generation: int = _generation
	var slice_start: int = Time.get_ticks_usec()
	var wanted: Dictionary[StringName, bool] = {}
	var origin: Vector2i = cell_at(player.global_position)
	var span: int = ceili((ACTIVE_RADIUS+_max_extent)/CELL_SIZE)+1
	for offset_x: int in range(-span,span+1):
		for offset_z: int in range(-span,span+1):
			var cell: Vector2i = origin+Vector2i(offset_x,offset_z)
			if not grid.has(cell):
				continue
			var ids: Array = grid[cell].keys()
			for id: StringName in ids:
				if is_required(id):
					wanted[id] = true
				if Time.get_ticks_usec()-slice_start>=FRAME_BUDGET_USEC:
					await get_tree().process_frame
					if generation != _generation:
						return
					slice_start = Time.get_ticks_usec()
	for id: StringName in active_nodes.keys():
		if not is_instance_valid(active_nodes[id]) or active_nodes[id].is_queued_for_deletion():
			active_nodes.erase(id)
		elif not wanted.has(id):
			active_nodes[id].hide()
			_despawn_queue.append(id)
		else:
			active_nodes[id].show()
	for id: StringName in wanted:
		if not active_nodes.has(id):
			_spawn_queue.append(id)
	var spawned_this_frame: int = 0
	var changes_this_frame: int = 0
	while not _spawn_queue.is_empty() or not _despawn_queue.is_empty():
		if not is_instance_valid(player) or not is_instance_valid(world_root):
			break
		if not _despawn_queue.is_empty():
			var id: StringName = _despawn_queue.pop_back()
			if not is_required(id):
				_despawn(id)
		elif not _spawn_queue.is_empty():
			var id: StringName = _spawn_queue.pop_back()
			if is_required(id):
				_spawn(id)
				spawned_this_frame += 1
		changes_this_frame += 1
		if spawned_this_frame>=MAX_SPAWNS_PER_FRAME or changes_this_frame>=MAX_NODE_CHANGES_PER_FRAME or Time.get_ticks_usec()-slice_start>=FRAME_BUDGET_USEC:
			await get_tree().process_frame
			if generation != _generation:
				return
			slice_start = Time.get_ticks_usec()
			spawned_this_frame = 0
			changes_this_frame = 0
	_working = false

func _spawn(id: StringName) -> void:
	if not entities.has(id) or active_nodes.has(id):
		return
	var entry: Dictionary = entities[id]
	var scene_key: StringName = entry.scene_key
	if not scene_cache.has(scene_key):
		if not _missing_resources.has(scene_key):
			_missing_resources[scene_key] = true
			resource_needed.emit(scene_key)
		return
	var position: Vector3 = entry.position
	if entry.snap_to_terrain:
		position = _terrain_position(id,position)
		if not position.is_finite():
			return
		entry.position = position
	var instance: Node3D = scene_cache[scene_key].instantiate() as Node3D
	if instance == null:
		spawn_failed.emit(id,"Scene cache phải có root Node3D")
		return
	instance.set_meta("world_entity_id",id)
	instance.set_meta("world_state",entry.state)
	instance.position = world_root.to_local(position)
	active_nodes[id] = instance
	world_root.add_child(instance)
	instance.reset_physics_interpolation()
	entity_spawned.emit(id,instance)

func _terrain_position(id: StringName, position: Vector3) -> Vector3:
	if not height_query.is_valid():
		spawn_failed.emit(id,"Chưa kết nối dữ liệu cao độ Terrain3D")
		return Vector3(NAN,NAN,NAN)
	var result: Variant = height_query.call(position)
	if (typeof(result)!=TYPE_FLOAT and typeof(result)!=TYPE_INT) or not is_finite(float(result)):
		spawn_failed.emit(id,"Vị trí nằm ngoài địa hình hoặc trong lỗ terrain")
		return Vector3(NAN,NAN,NAN)
	position.y = float(result)
	return position

func _despawn(id: StringName) -> void:
	if not active_nodes.has(id):
		return
	var instance: Node3D = active_nodes[id]
	active_nodes.erase(id)
	if is_instance_valid(instance):
		if instance.get_parent() != null:
			instance.get_parent().remove_child(instance)
		instance.queue_free()
	entity_despawned.emit(id)
