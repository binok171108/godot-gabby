extends Node

const Lod = preload("res://world_lod.gd")
const Policy = preload("res://world_stream_policy.gd")
var manifest: Dictionary
var loaded: Dictionary = {}
var host: Node
var scenery: Node3D
var busy := false
var last_cell := Vector2i(9999, 9999)
var last_focus := Vector2(INF,INF)
var requests := 0
var unloads := 0
var telemetry_clock := 0.0
var retry_at := 0
var max_scene_load_usec := 0
var max_scene_instantiate_usec := 0
var standby: Dictionary = {}
var preparing: Dictionary = {}
var prefetch_busy := false
var standby_hits := 0
var base_loaded: Dictionary = {}
var part_bounds: Dictionary = {}
const MAX_STANDBY_CELLS: int = 1
signal standby_ready

func initialize(owner_game: Node, parent: Node3D, focus: Vector2) -> bool:
	host = owner_game
	scenery = parent
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/world-cells.json"))
	part_bounds = JSON.parse_string(FileAccess.get_file_as_string("res://data/world-part-bounds.json"))
	host.streaming.register_provider(self)
	if not await AssetPacks.ensure_pack("world_base"):
		return false
	await refresh(focus, true)
	return true

func region_recipe(recipe: Dictionary, focus: Vector2) -> Dictionary:
	var selected: Dictionary = recipe.duplicate()
	var parts: Array[String] = []
	for path: String in recipe.get("parts", []):
		var values: Array = part_bounds[path]
		var bounds: Rect2 = Rect2(values[0], values[1], values[2], values[3])
		if Policy.should_load(bounds, focus, host.streaming.predicted):
			parts.append(path)
	selected["parts"] = parts
	return selected

func release_region(root: Node3D) -> void:
	host.streaming.unregister_visuals(root)
	for mesh in host.models.meshes(root):
		host.world_lod.unregister(mesh)
	host.stream_colliders = host.stream_colliders.filter(func(entry): return is_instance_valid(entry.shape) and not root.is_ancestor_of(entry.shape))
	root.get_parent().remove_child(root)
	root.queue_free()

func prune_parts(entry: Dictionary, focus: Vector2) -> void:
	var retained: Array[String] = []
	for child: Node in entry.node.get_children():
		var path: String = child.get_meta("chunk_part_path", "")
		if path.is_empty():
			continue
		var values: Array = part_bounds[path]
		var bounds: Rect2 = Rect2(values[0], values[1], values[2], values[3])
		if Policy.should_retain(bounds, focus, host.streaming.predicted):
			retained.append(path)
		else:
			release_region(child)
	entry["parts"] = retained

func refresh_base(focus: Vector2) -> void:
	for path in base_loaded.keys():
		var values: Array = manifest.base.regions[path]
		var bounds := Rect2(values[0],values[1],values[2],values[3])
		if Policy.should_retain(bounds,focus,host.streaming.predicted):
			continue
		var root: Node3D = base_loaded[path]
		release_region(root)
		base_loaded.erase(path)
		await get_tree().process_frame
	for path in manifest.base.parts:
		var values: Array = manifest.base.regions[path]
		var bounds := Rect2(values[0],values[1],values[2],values[3])
		if base_loaded.has(path) or not Policy.should_load(bounds,focus,host.streaming.predicted):
			continue
		var recipe := {"parts":[path]}
		var root: Node3D = await instantiate_recipe(recipe,false,false)
		if not root:
			return
		base_loaded[path] = root
		activate_scene(root)

func instantiate_scene(path: String, foreground: bool = true) -> Node3D:
	var started := Time.get_ticks_usec()
	var packed = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	max_scene_load_usec = maxi(max_scene_load_usec,Time.get_ticks_usec()-started)
	if not packed is PackedScene:
		if OS.has_feature("web"):
			AssetPacks.fail_pack("Không mở được cảnh: " + path, foreground)
		return null
	started = Time.get_ticks_usec()
	var instance: Node3D = packed.instantiate()
	host.models.restore_vertex_colors(instance)
	max_scene_instantiate_usec = maxi(max_scene_instantiate_usec,Time.get_ticks_usec()-started)
	packed = null
	return instance

func instantiate_recipe(recipe: Dictionary, foreground: bool, activate: bool = true) -> Node3D:
	if not recipe.has("parts"):
		return instantiate_scene(recipe.path,foreground)
	var root := Node3D.new()
	root.hide()
	root.process_mode = Node.PROCESS_MODE_DISABLED
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.set_meta("r3f_baked",true)
	scenery.add_child(root)
	var slice_start := Time.get_ticks_usec()
	for path in recipe.parts:
		var part := instantiate_scene(path,foreground)
		if not part:
			root.queue_free()
			return null
		for shape in part.find_children("*","CollisionShape3D",true,false):
			shape.disabled = true
		root.add_child(part)
		part.set_meta("chunk_part_path", path)
		await host.prepare_stream_scene(part,[],false)
		for node in part.find_children("*","MultiMeshInstance3D",true,false):
			RenderingServer.multimesh_set_physics_interpolated(node.multimesh.get_rid(),false)
			node.multimesh.reset_instances_physics_interpolation()
		if Time.get_ticks_usec()-slice_start>=2000:
			await host.streaming.checkpoint(Time.get_ticks_usec()-slice_start)
			slice_start = Time.get_ticks_usec()
	return root

func activate_scene(root: Node3D) -> void:
	host.register_stream_collisions(root)
	for mesh in host.models.meshes(root):
		host.world_lod.register_terrain(mesh,str(mesh.get_meta("r3f_source_name",mesh.name)))
	root.show()
	root.process_mode = Node.PROCESS_MODE_INHERIT
	host.streaming.register_visuals(root)
	host.streaming.update_visuals()
	host.world_lod.update(host.player.global_position)

func refresh(focus: Vector2, initial: bool = false) -> void:
	if busy or Time.get_ticks_msec() < retry_at:
		return
	var origin := Lod.cell_index(focus)
	if not initial and focus.distance_to(last_focus)<Policy.MOVE_THRESHOLD:
		return
	busy = true
	last_cell = origin
	last_focus = focus
	await refresh_base(focus)
	var wanted: Dictionary = {}
	var order: Array = []
	for key in manifest.cells:
		var coordinates: PackedStringArray = key.split(",")
		var cell := Vector2i(int(coordinates[0]), int(coordinates[1]))
		var bounds := Policy.cell_bounds(cell)
		if not Policy.should_load(bounds,focus,host.streaming.predicted):
			continue
		var state := "near" if Policy.state(bounds,focus)=="near" else "lod"
		if not manifest.cells[key].has(state):
			continue
		wanted[key] = state
		order.append({"key":key,"distance":Policy.distance(bounds,focus),"state":state})
	for key in loaded.keys():
		var fields: PackedStringArray = key.split(",")
		if not Policy.should_retain(Policy.cell_bounds(Vector2i(int(fields[0]),int(fields[1]))),focus,host.streaming.predicted):
			unload_cell(key)
		else:
			prune_parts(loaded[key], focus)
	order.sort_custom(func(first, second): return first.distance < second.distance)
	for item in order:
		if focus.distance_to(host.streaming.focus) > Policy.LOAD_RADIUS:
			busy = false
			last_focus = Vector2(INF, INF)
			return
		var recipe: Dictionary = region_recipe(manifest.cells[item.key][item.state], focus)
		if loaded.has(item.key) and loaded[item.key].state == item.state and loaded[item.key].parts == recipe.parts:
			continue
		var id: String = "cell_" + item.key.replace(",", "_") + "_" + item.state
		if initial:
			host.web_loading("Đang tải vùng %s (%s)…" % [item.key, item.state])
		var coordinates: PackedStringArray = item.key.split(",")
		var point := Vector2((float(coordinates[0])+0.5)*Lod.CELL_SIZE,(float(coordinates[1])+0.5)*Lod.CELL_SIZE)
		if not await host.streaming.request_pack(id,point,initial):
			busy = false
			last_cell = Vector2i(9999,9999)
			last_focus = Vector2(INF,INF)
			retry_at = Time.get_ticks_msec() + 1000
			return
		requests += 1
		while preparing.has(item.key) and item.state=="near":
			await standby_ready
		var root: Node3D
		if item.state=="near" and standby.has(item.key) and standby[item.key].get_meta("parts") == recipe.parts:
			root = standby[item.key]
			standby.erase(item.key)
			standby_hits += 1
		else:
			if standby.has(item.key):
				release_region(standby[item.key])
				standby.erase(item.key)
			root = await instantiate_recipe(recipe,initial)
		if not root:
			busy = false
			last_cell = Vector2i(9999,9999)
			last_focus = Vector2(INF,INF)
			retry_at = Time.get_ticks_msec() + 1000
			return
		if focus.distance_to(host.streaming.focus) > Policy.LOAD_RADIUS:
			release_region(root)
			busy = false
			last_focus = Vector2(INF, INF)
			return
		if root.get_parent()==null:
			root.hide()
			scenery.add_child(root)
			await host.prepare_stream_scene(root, recipe.nodes,false)
		if loaded.has(item.key):
			unload_cell(item.key)
		loaded[item.key] = {"state":item.state,"node":root,"parts":recipe.parts}
		activate_scene(root)
		await get_tree().process_frame
	busy = false

func prefetch(target: Vector2) -> void:
	if prefetch_busy or target.distance_to(host.streaming.focus)<Policy.MOVE_THRESHOLD:
		return
	prefetch_busy = true
	var order: Array = []
	for key in manifest.cells:
		var fields: PackedStringArray = key.split(",")
		var cell := Vector2i(int(fields[0]),int(fields[1]))
		if Policy.state(Policy.cell_bounds(cell),target)!="near" or not manifest.cells[key].has("near"):
			continue
		if standby.has(key) or (loaded.has(key) and loaded[key].state=="near"):
			continue
		var point := Vector2((cell.x+0.5)*Lod.CELL_SIZE,(cell.y+0.5)*Lod.CELL_SIZE)
		order.append({"key":key,"point":point,"distance":point.distance_to(target)})
	order.sort_custom(func(first,second): return first.distance<second.distance)
	for item in order:
		if standby.size() >= MAX_STANDBY_CELLS:
			break
		if standby.has(item.key) or (loaded.has(item.key) and loaded[item.key].state=="near"):
			continue
		if not host.streaming.in_cell_interest(item.point):
			continue
		preparing[item.key] = true
		var id: String = "cell_"+item.key.replace(",","_")+"_near"
		if await host.streaming.request_pack(id,item.point,false):
			var recipe: Dictionary = region_recipe(manifest.cells[item.key].near, host.streaming.focus)
			var root: Node3D = await instantiate_recipe(recipe,false,false)
			if root:
				if not host.streaming.in_near_interest(item.point):
					release_region(root)
				else:
					root.set_meta("parts", recipe.parts)
					standby[item.key] = root
		preparing.erase(item.key)
		standby_ready.emit()
	prefetch_busy = false

func stream_update() -> void:
	refresh(host.streaming.focus)
	if not busy:
		prefetch(host.streaming.predicted)
	for key in standby.keys():
		var fields: PackedStringArray = key.split(",")
		var point := Vector2((float(fields[0])+0.5)*Lod.CELL_SIZE,(float(fields[1])+0.5)*Lod.CELL_SIZE)
		if not host.streaming.in_near_interest(point):
			release_region(standby[key])
			standby.erase(key)

func unload_cell(key: String) -> void:
	var root: Node3D = loaded[key].node
	release_region(root)
	loaded.erase(key)
	unloads += 1

func info() -> Dictionary:
	var parts: int = 0
	for entry: Dictionary in loaded.values():
		parts += entry.parts.size()
	return {"cell":[last_cell.x,last_cell.y],"loaded":loaded.size(),"parts":parts,"baseRegions":base_loaded.size(),"requests":requests,"unloads":unloads,"busy":busy,"standbyHits":standby_hits,"maxSceneLoadUsec":max_scene_load_usec,"maxSceneInstantiateUsec":max_scene_instantiate_usec}

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.loading_room or host.picking_profile:
		return
	if not get_meta("streaming_managed",false):
		refresh(Vector2(host.player.position.x, host.player.position.z))
	telemetry_clock += delta
	if OS.has_feature("web") and telemetry_clock >= 0.5:
		telemetry_clock = 0
		var status := info()
		status["streaming"] = host.streaming.info()
		status["standby"] = standby.size()
		status["player"] = [host.player.position.x, host.player.position.y, host.player.position.z]
		status["steps"] = host.step_count
		status["floorRecoveries"] = host.floor_recoveries
		status["moveSpeed"] = host.actual_move_speed
		status["packDecodeUsec"] = AssetPacks.max_decode_usec
		status["packMountUsec"] = AssetPacks.max_mount_usec
		status["activeColliders"] = host.stream_colliders.filter(func(entry): return entry.active and is_instance_valid(entry.shape)).size()
		status["routePoints"] = host.map_route.size()
		status["waypoint"] = [host.map_route[0].x,host.map_route[0].y] if not host.map_route.is_empty() else []
		status["fps"] = Engine.get_frames_per_second()
		status["drawCalls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		status["triangles"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		status["cameraYaw"] = host.camera_yaw
		if is_instance_valid(host.lawn_stream):
			status["lawn"] = host.lawn_stream.info()
		status["goal"] = host.map_goal
		status["mapOpen"] = host.map_open
		status["lastUIInput"] = host.last_ui_input
		if host.map_open:
			var buttons: Array = []
			for button in host.touch_buttons:
				if is_instance_valid(button) and button.is_visible_in_tree() and button.text in ["Doraemon","ĐÓNG"]:
					var rect: Rect2 = button.get_global_rect()
					buttons.append({"text":button.text,"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y})
			status["mapButtons"] = buttons
		if is_instance_valid(host.entity_stream):
			status["entities"] = host.entity_stream.info()
		if is_instance_valid(host.tree_forest):
			status["trees"] = host.tree_forest.stats
			status["treeUploads"] = host.tree_forest.buffer_updates
		JavaScriptBridge.eval("window.gabbyStreamInfo=%s" % JSON.stringify(status))
