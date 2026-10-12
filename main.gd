extends Node3D

signal loading_status_changed(message: String)

const State = preload("res://game_state.gd")
const Models = preload("res://assets.gd")
const Controls = preload("res://touch_controls.gd")
const Games = preload("res://mini_games.gd")
const Profiles = preload("res://profile_store.gd")
const Lod = preload("res://world_lod.gd")
const Navigation = preload("res://navigation.gd")
const MapView = preload("res://world_map.gd")
const FollowCamera = preload("res://follow_camera.gd")
const PlayerMotion = preload("res://player_motion.gd")
var content: Dictionary
var state: RefCounted
var models := Models.new()
var world_lod := Lod.new()
var world_stream: Node
var streaming: Node
var entity_stream: Node
var tree_forest: Node3D
var lawn_stream: Node3D
var traffic: Node3D
var train: Node3D
var scenery: Node3D
var player: CharacterBody3D
var avatar: Node3D
var camera: Camera3D
var orbit: RefCounted
var minimap: Control
var navigation := Navigation.new()
var map_goal: Dictionary = {}
var map_open := false
var map_route: Array[Vector2] = []
var route_stuck := 0.0
var step_count := 0
var floor_recoveries := 0
var actual_move_speed := 0.0
var camera_touches: Dictionary = {}
var ui_finger := -1
var ui_button: Button
var ui_origin := Vector2.ZERO
var ui_last := Vector2.ZERO
var ui_dragged := false
var ui_scroll: ScrollContainer
var last_ui_input: Dictionary = {}
var hud: Control
var controls: Control
var panel: PanelContainer
var panel_body: VBoxContainer
var option_parent: Control
var option_columns := 1
var title: Label
var hint: Label
var touch_buttons: Array[Button] = []
var targets: Array[Dictionary] = []
var keyboard: Dictionary = {}
var games: Node
var jump_count := 0
var clock := 0.0
var telemetry_clock := 0.0
var camera_yaw := 0.0
var look_finger := -1
var look_position := Vector2.ZERO
var mouse_looking := false
var loading_room := false
var web_collision_pending: Array[MeshInstance3D] = []
var web_collision_index := 0
var stream_ground_material: ShaderMaterial
var stream_water_material: ShaderMaterial
var stream_colliders: Array[Dictionary] = []
var stream_collision_index := 0
var room_label := ""
var nearest: Dictionary = {}
var carried_model: Node3D
var profiles: RefCounted
var profile_layer: CanvasLayer
var profile_screen: Control
var picking_profile := false
var pin_buffer := ""
var pin_dots: Label
var pin_message: Label
var profile_button: Button
var pin_profile_id := ""

func _ready() -> void:
	Engine.max_fps = 60
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	models.required_ai.append("com-kit")
	for friend in content.world.friends:
		if friend.has("model"):
			models.required_ai.append(friend.model)
	for asset in models.required_ai:
		if OS.has_feature("web") and asset != "com-kit":
			continue
		if not ResourceLoader.exists("res://assets/ai/" + asset + ".glb"):
			var message := "Thiếu model nhân vật bắt buộc: " + asset
			push_error(message)
			if OS.has_feature("web"):
				JavaScriptBridge.eval("fail(%s)" % JSON.stringify(message))
			return
	state = State.new(content)
	profiles = Profiles.new(content)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a8dbea")
	environment.environment.fog_enabled = true
	environment.environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.environment.fog_density = 1.0
	environment.environment.fog_depth_begin = 100.0
	environment.environment.fog_depth_end = 160.0
	environment.environment.fog_light_color = Color("a8dbea")
	environment.environment.fog_sky_affect = 0.0
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff2e1")
	environment.environment.ambient_light_energy = 0.25
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	add_child(sun)
	player = CharacterBody3D.new()
	player.name = "Com"
	player.safe_margin = 0.005
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.65
	collider.shape = shape
	collider.position.y = 0.83
	player.add_child(collider)
	add_child(player)
	streaming = preload("res://world_streaming.gd").new()
	add_child(streaming)
	streaming.initialize(self)
	avatar = models.instantiate("com-kit")
	player.add_child(avatar)
	fit_actor(avatar, "com-kit", 1.8)
	apply_outfit(state.outfit)
	camera = Camera3D.new()
	camera.near = 0.3
	camera.far = 400
	add_child(camera)
	camera.current = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	make_hud()
	games = Games.new()
	games.host = self
	add_child(games)
	if not OS.has_feature("web"):
		enter_room("world")
	show_profiles()
	get_window().focus_exited.connect(func(): keyboard.clear(); controls.release(); look_finger = -1; mouse_looking = false; camera_touches.clear())
	get_viewport().size_changed.connect(func(): look_finger = -1; mouse_looking = false; controls.release(); camera_touches.clear())
	if OS.has_feature("web"):
		get_viewport().disable_3d = true
		await get_tree().process_frame
		await get_tree().process_frame
		web_loading("ready")

func web_loading(message: String, current: int = 0, total: int = 0) -> void:
	loading_status_changed.emit(message)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gabbyLoadStatus(%s,%d,%d)" % [JSON.stringify(message), current, total])

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

func fit_actor(model: Node3D, asset: String, height: float) -> void:
	if content.assetHeights.has(asset):
		model.scale = Vector3.ONE * height / float(content.assetHeights[asset])
	else:
		models.fit(model, height)

func box(parent: Node3D, point: Vector3, size: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = point
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size
		shape.shape = cube
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func label3d(parent: Node3D, text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.008
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.modulate = Color("fff9ef")
	parent.add_child(label)

func add_target(kind: String, definition: Dictionary, point: Vector3) -> void:
	targets.append({"kind":kind,"data":definition,"point":point})

func enter_room(id: String) -> void:
	if loading_room:
		return
	loading_room = true
	if OS.has_feature("web"):
		web_loading("Đang dựng phòng và cảnh 3D…")
		get_viewport().disable_3d = true
		await get_tree().process_frame
		await get_tree().process_frame
		if id != "world" and not await AssetPacks.ensure_pack("rooms"):
			return
	close_panel()
	controls.release()
	keyboard.clear()
	targets.clear()
	web_collision_pending.clear()
	stream_colliders.clear()
	stream_collision_index = 0
	world_lod.clear()
	streaming.providers.clear()
	streaming.visuals.clear()
	if is_instance_valid(world_stream):
		remove_child(world_stream)
		world_stream.queue_free()
		world_stream = null
	if is_instance_valid(entity_stream):
		remove_child(entity_stream)
		entity_stream.queue_free()
		entity_stream = null
	cancel_map_goal()
	tree_forest = null
	lawn_stream = null
	traffic = null
	train = null
	web_collision_index = 0
	if scenery:
		remove_child(scenery)
		scenery.queue_free()
	scenery = Node3D.new()
	add_child(scenery)
	state.room_id = id
	player.velocity = Vector3.ZERO
	if id == "world":
		await build_world()
	else:
		build_room(content.rooms[id])
	refresh_carried()
	player.reset_physics_interpolation()
	title.text = "NHÀ BÚP BÊ CẦU VỒNG  /  " + room_label
	if OS.get_environment("GABBY_TEST") != "1":
		state.save()
	if OS.has_feature("web"):
		get_viewport().disable_3d = false
		web_loading("Đang chuẩn bị khung hình đầu tiên…")
		if id=="world":
			await preload("res://render_warmup.gd").prepare(self)
		await RenderingServer.frame_post_draw
		web_loading("ready")
	loading_room = false

func build_room(room: Dictionary) -> void:
	room_label = room.name
	var bounds: Dictionary = room.bounds
	box(scenery, Vector3(0, -0.15, 0), Vector3(bounds.maxX * 2 + 1.8, 0.3, bounds.maxZ * 2 + 1.8), Color(room.color).lightened(0.32))
	box(scenery, Vector3(0, 2.7, bounds.minZ - 0.75), Vector3(bounds.maxX * 2 + 1.8, 5.4, 0.2), Color(room.accent).lightened(0.2))
	box(scenery, Vector3(bounds.minX - 0.75, 2.7, 0), Vector3(0.2, 5.4, bounds.maxZ * 2 + 1.8), Color(room.color).lightened(0.18))
	var decor := models.instantiate("decor-" + room.id, false)
	scenery.add_child(decor)
	for mesh in models.meshes(decor):
		if mesh.mesh and mesh.get_aabb().size.y > 0.3:
			mesh.create_trimesh_collision()
	build_objects(room.id)
	for door in room.doors:
		box(scenery, Vector3(door.x, 1.1, door.z), Vector3(0.15, 2.2, 1.1), Color(room.accent), false)
		label3d(scenery, door.label, Vector3(door.x, 2.7, door.z))
		add_target("door", door, Vector3(door.x, 0, door.z))
	var npc_asset: String = "npc-" + room.id
	if room.id == "com":
		npc_asset = "gabby"
	elif room.id == "pillow":
		npc_asset = "pillow-cat"
	var npc := models.instantiate(npc_asset)
	scenery.add_child(npc)
	fit_actor(npc, npc_asset, 1.85)
	npc.position = Vector3(0, npc.position.y, -1.2)
	models.animate(npc, "idle")
	label3d(scenery, room.npc, Vector3(0, 2.4, -1.2))
	add_target("npc", room, Vector3(0, 0, -1.2))
	player.position = Vector3(room.start.x, 0.15, room.start.z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	camera.position = Vector3(11, 14, 17)
	camera.look_at(Vector3(0, 1, 0))

func build_objects(room: String) -> void:
	for original_room in content.roomOrder:
		for definition in content.rooms[original_room].objects:
			var key: String = original_room + ":" + definition.id
			var placement: Dictionary = state.placements.get(key, {"room":original_room,"x":definition.x,"z":definition.z})
			if placement.get("room", original_room) != room or state.carried.get("key", "") == key:
				continue
			var model := models.instantiate("object-" + definition.id, false)
			scenery.add_child(model)
			model.position = Vector3(placement.x, placement.get("y", 0), placement.z)
			var object: Dictionary = definition.duplicate()
			object["originKey"] = key
			add_target("object", object, model.position)

func build_world() -> void:
	room_label = "Thế giới hoạt hình"
	var world: Dictionary = content.world
	player.position = Vector3(world.start.x,0.2,world.start.z)
	streaming.initialize(self)
	var streamed := FileAccess.file_exists("res://data/world-cells.json")
	var snapshot := streamed or ResourceLoader.exists("res://assets/r3f-world.glb")
	if streamed:
		world_stream = load("res://world_stream.gd").new()
		add_child(world_stream)
		await world_stream.initialize(self, scenery, Vector2(world.start.x, world.start.z))
	elif snapshot:
		var original_world := models.instantiate("r3f-world", false)
		scenery.add_child(original_world)
		restore_source_nodes(original_world)
		restore_instances(original_world)
		var world_meshes := models.meshes(original_world)
		var terrain_material := create_ground_material()
		var completed := 0
		for mesh in world_meshes:
			completed += 1
			if OS.has_feature("web") and completed % 16 == 0:
				web_loading("Đang dựng vật liệu và va chạm…", completed, world_meshes.size())
				await get_tree().process_frame
			var label := str(mesh.get_meta("r3f_source_name", mesh.name)).to_lower()
			if label.begins_with("terrain-"):
				world_lod.register_terrain(mesh, label)
				mesh.material_override = terrain_material
			if not mesh.visible:
				continue
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if label.begins_with("terrain-") or label == "textured-meadow":
				mesh.material_override = terrain_material
			if label.contains("sky") or label.begins_with("board-") or label.begins_with("sign-"):
				mesh.hide()
				continue
			if mesh.mesh and not mesh.get_meta("r3f_house_mesh", false) and not label.contains("water") and not label.contains("leaf") and not label.contains("canopy") and not label.contains("foliage"):
				if not OS.has_feature("web") or collision_is_near(mesh, Vector3(world.start.x, 0, world.start.z)):
					mesh.create_trimesh_collision()
				else:
					web_collision_pending.append(mesh)
	else:
		box(scenery, Vector3(0, -0.2, -40), Vector3(205, 0.4, 345), Color("89b77c"))
	if snapshot and FileAccess.file_exists("res://assets/r3f-house-colliders.json"):
		var house_colliders: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/r3f-house-colliders.json"))
		for collider in house_colliders:
			var body := StaticBody3D.new()
			body.name = "R3FHouseCollider"
			body.position = Vector3(collider.x, collider.y, collider.z)
			body.rotation.y = collider.yaw
			var shape := BoxShape3D.new()
			shape.size = Vector3(collider.w, collider.h, collider.d)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
			scenery.add_child(body)
	for road in ([] if snapshot else world.roads):
		for index in range(1, road.size()):
			var start := Vector3(road[index - 1][0], 0.03, road[index - 1][1])
			var end := Vector3(road[index][0], 0.03, road[index][1])
			var segment := box(scenery, (start + end) / 2, Vector3(6, 0.06, start.distance_to(end)), Color("8f949c"), false)
			segment.rotation.y = atan2(end.x - start.x, end.z - start.z)
	for water in ([] if snapshot else [[43, 10], [107, 14]]):
		box(scenery, Vector3(0, 0.02, water[0]), Vector3(200, 0.04, water[1]), Color("61bdcd"), false)
	for water in world.waterBoxes:
		var obstacle := box(scenery, Vector3((water.minX + water.maxX) / 2, -1, (water.minZ + water.maxZ) / 2), Vector3(water.maxX - water.minX, 4, water.maxZ - water.minZ), Color.WHITE)
		obstacle.visible = false
	for place in world.places:
		var asset: String = ""
		if place.id == "gabby-house":
			asset = "dollhouse"
		elif place.has("prop"):
			asset = "dream/" + place.prop
		elif place.has("model"):
			asset = place.model
		if not snapshot and not asset.is_empty():
			var model := models.instantiate(asset, false)
			scenery.add_child(model)
			model.position = Vector3(place.x + place.get("propX", 0), 0, place.z + place.get("propZ", 0))
			if asset == "dollhouse":
				models.fit(model, 24)
			for mesh in models.meshes(model):
				if mesh.mesh:
					mesh.create_trimesh_collision()
		label3d(scenery, place.name, Vector3(place.x, 6, place.z + 8))
		if not snapshot:
			add_target("place", place, Vector3(place.x, 0, place.z + 9))
	for friend in world.friends:
		add_target("friend", friend, Vector3(friend.x, traffic_ground_height(Vector2(friend.x,friend.z)), friend.z))
	entity_stream = load("res://entity_stream.gd").new()
	add_child(entity_stream)
	await entity_stream.initialize(self)
	build_objects("world")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 65
	camera_yaw = 0
	camera.position = player.position + Vector3(0,5.8,11)
	camera.look_at(player.position + Vector3(0,1.2,0))
	orbit = FollowCamera.new()
	orbit.initialize(self)
	if FileAccess.file_exists("res://data/tree-kit.json"):
		if await AssetPacks.ensure_pack("trees"):
			tree_forest = load("res://tree_forest.gd").new()
			scenery.add_child(tree_forest)
			tree_forest.initialize(self)
	if FileAccess.file_exists("res://data/traffic.json"):
		if await AssetPacks.ensure_pack("traffic"):
			traffic = load("res://traffic.gd").new()
			scenery.add_child(traffic)
			traffic.initialize(self)
	if FileAccess.file_exists("res://data/train.json"):
		if await AssetPacks.ensure_pack("train"):
			train = load("res://train.gd").new()
			scenery.add_child(train)
			train.initialize(self)
	if FileAccess.file_exists("res://data/lawn-stream.json"):
		lawn_stream = load("res://lawn_stream.gd").new()
		scenery.add_child(lawn_stream)
		await lawn_stream.initialize(self)
	streaming.register_visuals(scenery)
	streaming.update_visuals()

func create_ground_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://ground.gdshader")
	for entry in [["lawn_texture","grass-kit/Ground_LawnSmooth.jpg"],["path_texture","grass-kit/Ground_DirtPath.jpg"],["dry_texture","grass-kit/Ground_DirtDry.jpg"],["mask_texture","grass-kit/WorldMask_Lawn.png"],["lane_texture","grass-kit/lane-mask.png"],["rock_texture","textures/dream/rock.webp"]]:
		var path: String = "res://assets/" + entry[1]
		if ResourceLoader.exists(path):
			result.set_shader_parameter(entry[0], load(path))
	return result

func collision_is_near(mesh: MeshInstance3D, point: Vector3) -> bool:
	var bounds := mesh.global_transform * mesh.get_aabb()
	var closest := point.clamp(bounds.position, bounds.end)
	return closest.distance_squared_to(point) <= 400.0

func prepare_nearby_collisions() -> void:
	for attempt in range(mini(16, web_collision_pending.size())):
		if web_collision_pending.is_empty():
			return
		web_collision_index %= web_collision_pending.size()
		var mesh := web_collision_pending[web_collision_index]
		if not is_instance_valid(mesh):
			web_collision_pending.remove_at(web_collision_index)
		elif collision_is_near(mesh, player.global_position):
			mesh.create_trimesh_collision()
			web_collision_pending.remove_at(web_collision_index)
			return
		else:
			web_collision_index += 1

func register_stream_collisions(root: Node3D) -> void:
	for shape in root.find_children("*","CollisionShape3D",true,false):
		var mesh = shape.get_parent().get_parent()
		if not mesh is MeshInstance3D:
			continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		var active: bool = streaming.is_detailed(preload("res://world_stream_policy.gd").horizontal_bounds(bounds))
		shape.disabled = not active
		shape.get_parent().set_meta("stream_part",root.scene_file_path)
		stream_colliders.append({"shape":shape,"bounds":bounds,"active":active})

func update_stream_collisions() -> void:
	for attempt in range(mini(64,stream_colliders.size())):
		if stream_colliders.is_empty():
			return
		stream_collision_index %= stream_colliders.size()
		var entry: Dictionary = stream_colliders[stream_collision_index]
		if not is_instance_valid(entry.shape) or entry.shape.is_queued_for_deletion():
			stream_colliders.remove_at(stream_collision_index)
			continue
		var bounds: AABB = entry.bounds
		var region := preload("res://world_stream_policy.gd").horizontal_bounds(bounds)
		var active: bool = streaming.is_active(region) if entry.active else streaming.is_detailed(region)
		if active!=entry.active:
			entry.active = active
			entry.shape.set_deferred("disabled",not active)
		stream_collision_index += 1

func restore_instances(root: Node3D, supplied_records: Array = []) -> void:
	if not FileAccess.file_exists("res://assets/r3f-instances.json"):
		return
	var records: Array = supplied_records if not supplied_records.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://assets/r3f-instances.json"))
	var buffer := FileAccess.get_file_as_bytes("res://assets/r3f-instances.bin").to_float32_array()
	for record in records:
		var original = root.find_child(record.name, true, false)
		if not original is MeshInstance3D:
			push_error("Thiếu mesh instancing R3F: " + record.name)
			continue
		var instanced := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = original.mesh
		for surface in range(original.mesh.get_surface_count()):
			var source_material = original.mesh.surface_get_material(surface)
			if source_material is StandardMaterial3D:
				source_material.vertex_color_use_as_albedo = true
		multimesh.instance_count = record.count
		if record.has("indices"):
			var selected := PackedFloat32Array()
			for index in record.indices:
				selected.append_array(buffer.slice(record.offset + int(index) * 16, record.offset + int(index) * 16 + 16))
			multimesh.buffer = selected
		else:
			multimesh.buffer = buffer.slice(record.offset, record.offset + record.length)
		instanced.multimesh = multimesh
		instanced.material_override = original.material_override
		if original.get_meta("r3f_grass", false):
			var source_material = original.mesh.surface_get_material(0)
			if source_material is StandardMaterial3D and source_material.albedo_texture:
				var grass := ShaderMaterial.new()
				grass.shader = load("res://grass.gdshader")
				grass.set_shader_parameter("base_texture", source_material.albedo_texture)
				grass.set_shader_parameter("tint", source_material.albedo_color)
				grass.set_shader_parameter("alpha_cutoff", 0.5)
				instanced.material_override = grass
		instanced.transform = original.transform
		instanced.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instanced.visible = original.visible
		original.get_parent().add_child(instanced)
		original.hide()

func restore_source_nodes(root: Node3D, supplied_records: Array = []) -> void:
	if not FileAccess.file_exists("res://assets/r3f-nodes.json"):
		return
	var records: Array = supplied_records if not supplied_records.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://assets/r3f-nodes.json"))
	var nodes: Dictionary = {}
	for mesh in models.meshes(root):
		nodes[str(mesh.name)] = mesh
	for record in records:
		if nodes.has(record.name):
			var mesh: MeshInstance3D = nodes[record.name]
			mesh.visible = record.visible
			mesh.set_meta("r3f_source_name", record.sourceName)
			mesh.set_meta("r3f_grass", record.get("grass", false))
			mesh.set_meta("r3f_house_mesh", record.get("houseMesh", false))

func prepare_stream_scene(root: Node3D, records: Array, activate: bool = true) -> void:
	var baked: bool = root.get_meta("r3f_baked",false)
	if baked and activate:
		register_stream_collisions(root)
	if not baked:
		restore_source_nodes(root, records)
	var instances: Array = []
	for record in records:
		if record.has("instance"):
			instances.append(record.instance)
	if not baked and not instances.is_empty():
		restore_instances(root, instances)
	if not stream_ground_material:
		stream_ground_material = create_ground_material()
	if not stream_water_material:
		stream_water_material = ShaderMaterial.new()
		stream_water_material.shader = load("res://water.gdshader")
		stream_water_material.set_shader_parameter("ripple",load("res://assets/textures/dream/water-ripple.webp"))
	var terrain_material := stream_ground_material
	var water_material := stream_water_material
	var completed := 0
	for mesh in models.meshes(root):
		var label := str(mesh.get_meta("r3f_source_name", mesh.name)).to_lower()
		if label.begins_with("terrain-"):
			mesh.material_override = terrain_material
			if activate:
				world_lod.register_terrain(mesh, label)
			if not baked and label.ends_with("-lod2"):
				mesh.create_trimesh_collision()
		elif label.contains("water"):
			mesh.material_override = water_material
		elif not baked and mesh.visible and not mesh.get_meta("r3f_house_mesh", false) and not label.contains("water") and not label.contains("leaf") and not label.contains("canopy") and not label.contains("foliage"):
			if loading_room and collision_is_near(mesh, player.position):
				mesh.create_trimesh_collision()
			else:
				web_collision_pending.append(mesh)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		completed += 1
		if OS.has_feature("web") and completed % (16 if loading_room else 2) == 0:
			await get_tree().process_frame

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var theme := Theme.new()
	theme.default_font_size = 23
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff7e8")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", style)
	theme.set_stylebox("hover", "Button", style)
	theme.set_stylebox("pressed", "Button", style)
	theme.set_color("font_color", "Button", Color("283d52"))
	hud.theme = theme
	title = Label.new()
	title.position = Vector2(24, 18)
	title.custom_minimum_size = Vector2(520, 44)
	title.size = Vector2(520, 44)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("243a50"))
	hud.add_child(title)
	profile_button = button(hud, "NGƯỜI CHƠI", Vector2(570, 15), Vector2(198, 48), show_profiles)
	button(hud, "CAMERA", Vector2(780, 15), Vector2(130, 48), func():
		if orbit:
			orbit.reset())
	button(hud, "BẢN ĐỒ", Vector2(922,15),Vector2(150,48),show_world_map)
	button(hud, "TRANG PHỤC", Vector2(1089, 15), Vector2(170, 48), show_outfits)
	hint = Label.new()
	hint.position = Vector2(260, 658)
	hint.size = Vector2(660, 52)
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("fff7e8"))
	var hint_background := StyleBoxFlat.new()
	hint_background.bg_color = Color(0.08, 0.14, 0.23, 0.9)
	hint_background.content_margin_left = 12
	hint_background.content_margin_top = 6
	hint.add_theme_stylebox_override("normal", hint_background)
	hud.add_child(hint)
	if FileAccess.file_exists("res://data/world-map.json"):
		minimap = MapView.new()
		hud.add_child(minimap)
		minimap.initialize(self)
		minimap.map_requested.connect(show_world_map)
	controls = Controls.new()
	hud.add_child(controls)
	controls.jump_requested.connect(jump)
	controls.interact_requested.connect(interact)
	panel = PanelContainer.new()
	panel.position = Vector2(230, 90)
	panel.size = Vector2(820, 510)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("25394c")
	background.content_margin_left = 25
	background.content_margin_right = 25
	background.content_margin_top = 18
	background.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", background)
	hud.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 12)
	scroll.add_child(panel_body)
	panel.hide()

func button(parent: Node, text: String, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.clip_text = true
	result.position = point
	result.custom_minimum_size = dimensions
	result.size = dimensions
	result.pressed.connect(action)
	parent.add_child(result)
	touch_buttons.append(result)
	return result

func open_panel(heading: String) -> void:
	map_open = false
	controls.release()
	controls.enabled = false
	controls.queue_redraw()
	for child in panel_body.get_children():
		panel_body.remove_child(child)
		child.queue_free()
	panel.show()
	option_parent = panel_body
	option_columns = 1
	var row := HBoxContainer.new()
	panel_body.add_child(row)
	var label := Label.new()
	label.text = heading
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	button(row, "ĐÓNG", Vector2.ZERO, Vector2(100, 45), close_panel)

func paragraph(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 700
	panel_body.add_child(label)
	return label

func option(text: String, action: Callable) -> Button:
	return button(option_parent, text, Vector2.ZERO, Vector2(720.0 / option_columns - 10, 48), action)

func choice_grid(columns: int = 2) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panel_body.add_child(grid)
	option_parent = grid
	option_columns = columns

func close_panel() -> void:
	if not panel:
		return
	panel.hide()
	map_open = false
	controls.enabled = not picking_profile
	controls.queue_redraw()
	touch_buttons = touch_buttons.filter(func(item): return is_instance_valid(item))

func show_world_map() -> void:
	if picking_profile or loading_room or state.room_id != "world" or not FileAccess.file_exists("res://data/world-map.json"):
		return
	open_panel("BẢN ĐỒ — chạm để Cốm tự đi tới")
	map_open = true
	if not map_goal.is_empty():
		paragraph("Đang đi tới " + str(map_goal.name))
		option("DỪNG ĐI", func(): cancel_map_goal(); show_world_map())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	panel_body.add_child(row)
	var view := MapView.new()
	row.add_child(view)
	view.initialize(self,true)
	view.destination_selected.connect(func(point: Vector2): set_map_goal(point,"chỗ đã chọn"))
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(360,320/view.data.aspect)
	list_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(list_scroll)
	var list := VBoxContainer.new()
	list_scroll.add_child(list)
	var data: Dictionary = view.data
	for friend in data.friends:
		button(list,friend.name,Vector2.ZERO,Vector2(350,45),set_map_goal.bind(Vector2(friend.x,friend.z+2),friend.name))
	for place in data.places:
		if place.kind in ["canal","river"]:
			continue
		button(list,place.name,Vector2.ZERO,Vector2(350,45),set_map_goal.bind(Vector2(place.x,place.z+3),place.name))

func set_map_goal(point: Vector2, name: String) -> void:
	last_ui_input["destination"] = name
	last_ui_input["navigation"] = navigation.ready()
	if not navigation.ready():
		paragraph("Lõi tìm đường chưa sẵn sàng, hãy thử lại sau.")
		return
	map_goal = {"x":point.x,"z":point.y,"name":name}
	map_route = navigation.path(Vector2(player.position.x,player.position.z),point)
	route_stuck = 0
	close_panel()

func cancel_map_goal() -> void:
	map_goal.clear()
	map_route.clear()
	route_stuck = 0

func traffic_ground_height(point: Vector2) -> float:
	return preload("res://traffic_sim.gd").dream_height(point)

func profile_layout(heading: String) -> VBoxContainer:
	if not profile_layer:
		profile_layer = CanvasLayer.new()
		profile_layer.layer = 10
		add_child(profile_layer)
	if profile_screen:
		profile_layer.remove_child(profile_screen)
		profile_screen.queue_free()
	profile_screen = Control.new()
	profile_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_screen.theme = hud.theme
	profile_layer.add_child(profile_screen)
	var background := ColorRect.new()
	background.color = Color("f5eafa")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_screen.add_child(background)
	var body := VBoxContainer.new()
	body.position = Vector2(280, 100)
	body.size = Vector2(720, 520)
	body.add_theme_constant_override("separation", 24)
	profile_screen.add_child(body)
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.add_theme_font_size_override("font_size", 44)
	heading_label.add_theme_color_override("font_color", Color("4f345f"))
	body.add_child(heading_label)
	return body

func show_profiles() -> void:
	if not picking_profile and not state.profile_id.is_empty():
		state.save()
	picking_profile = true
	pin_profile_id = ""
	keyboard.clear()
	controls.release()
	controls.enabled = false
	hud.hide()
	var body := profile_layout("Ai đang chơi nào?")
	for profile in content.profiles:
		var label: String = profile.name + ("  ·  Cần mật khẩu" if profile.has("pin") else "  ·  Vào chơi ngay")
		button(body, label, Vector2.ZERO, Vector2(720, 100), func():
			if profile.has("pin"):
				show_pin(profile)
			else:
				select_profile(profile.id))

func show_pin(profile: Dictionary) -> void:
	pin_buffer = ""
	pin_profile_id = profile.id
	var body := profile_layout("Nhập mật khẩu của " + profile.name)
	data_pin_labels(body)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for digit in ["1","2","3","4","5","6","7","8","9","","0","⌫"]:
		var key := button(grid, digit, Vector2.ZERO, Vector2(225, 52), func(): press_pin(profile.id, digit))
		key.disabled = digit.is_empty()
	button(body, "← Chọn người khác", Vector2.ZERO, Vector2(720, 48), show_profiles)

func data_pin_labels(body: VBoxContainer) -> void:
	pin_dots = Label.new()
	pin_dots.text = "○○○○○○"
	pin_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_dots.add_theme_font_size_override("font_size", 35)
	pin_dots.add_theme_color_override("font_color", Color("4f345f"))
	body.add_child(pin_dots)
	pin_message = Label.new()
	pin_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_message.add_theme_color_override("font_color", Color("9a3457"))
	body.add_child(pin_message)

func press_pin(id: String, digit: String) -> void:
	if digit == "⌫":
		pin_buffer = pin_buffer.left(maxi(0, pin_buffer.length() - 1))
	elif pin_buffer.length() < 6:
		pin_buffer += digit
	pin_dots.text = "●".repeat(pin_buffer.length()) + "○".repeat(6 - pin_buffer.length())
	if pin_buffer.length() == 6:
		if not select_profile(id, pin_buffer):
			pin_message.text = "Sai mật khẩu rồi, thử lại nhé!"
			pin_buffer = ""
			pin_dots.text = "○○○○○○"

func select_profile(id: String, pin: String = "") -> bool:
	var next = profiles.load_profile(id, pin)
	if not next:
		return false
	state = next
	picking_profile = false
	pin_profile_id = ""
	profile_layer.remove_child(profile_screen)
	profile_screen.queue_free()
	profile_screen = null
	hud.show()
	profile_button.text = profiles.definition(id).name + "  ▾"
	profile_button.tooltip_text = "Đổi người chơi"
	apply_outfit(state.outfit)
	enter_room(state.room_id)
	return true

func show_rooms() -> void:
	open_panel("Khám phá ngôi nhà")
	choice_grid()
	option("Thế giới hoạt hình", func(): enter_room("world"))
	for id in content.roomOrder:
		option(content.rooms[id].name, func(): enter_room(id))

func show_games() -> void:
	open_panel("Trò chơi Godot")
	choice_grid()
	for definition in [["math", "Toán vui"], ["spelling", "Chính tả"], ["memory", "Tìm cặp hình"], ["caro", "Cờ caro"], ["cooking", "Nấu ăn cùng Cakey"], ["origami", "Gấp giấy"], ["piano", "Đàn piano"], ["draw", "Vẽ tranh"], ["english", "Tiếng Anh"], ["science", "Khoa học"], ["quests", "Nhiệm vụ & sticker"]]:
		option(definition[1], func(): games.start(definition[0]))

func show_outfits() -> void:
	open_panel("Trang phục của Cốm")
	choice_grid()
	for outfit in content.outfits:
		option(outfit.label, func(): apply_outfit(outfit.id); close_panel())

func apply_outfit(id: String) -> void:
	for outfit in content.outfits:
		if outfit.id == id:
			state.outfit = id
			models.set_look(avatar, outfit.look)
			if OS.get_environment("GABBY_TEST") != "1":
				state.save()
			return

func jump() -> void:
	if player.is_on_floor() and not panel.visible and not picking_profile and not (train and train.riding):
		player.velocity.y = 5
		jump_count += 1
		games.tone(660)

func interact() -> void:
	if panel.visible or picking_profile:
		return
	if train and train.riding:
		train.leave()
		return
	if not state.carried.is_empty():
		var key: String = state.carried.key
		state.placements[key] = {"room":state.room_id,"x":player.position.x + 0.6,"y":maxf(0, player.position.y),"z":player.position.z}
		state.carried = {}
		reload_room()
		return
	if nearest.is_empty():
		if train and not train.station_near().is_empty():
			train.board()
		return
	var data: Dictionary = nearest.data
	match nearest.kind:
		"door":
			enter_room(data.to)
		"object":
			open_panel(data.label)
			for action in content.actions.get(data.id, []):
				option(action.label, func():
					if action.has("game"):
						games.start(action.game)
					else:
						state.perform(data.id, action.id)
						games.tone(880)
						paragraph("Cốm " + action.get("verb", action.label) + "!")
						state.save())
			if data.get("portable", false):
				option("Cầm theo", func(): state.carried = {"key":data.originKey,"id":data.id}; reload_room())
		"npc":
			open_panel(data.npc)
			paragraph(data.npcDialogue.intro)
			for choice in data.npcDialogue.choices:
				option(choice.label, func():
					if choice.has("game"):
						games.start(choice.game)
					else:
						paragraph(choice.reply)
						state.reward("dialogue:" + data.id + ":" + choice.id)
						state.save())
		"friend":
			open_panel(data.name)
			paragraph(data.line)
			option(data.action, func(): paragraph(data.reply); state.reward("friend:" + data.id); state.save())
		"place":
			state.reward("visit:" + data.id)
			state.save()
			if data.id == "gabby-house":
				enter_room("foyer")
			else:
				open_panel(data.name)
				paragraph("Địa điểm gốc đã chuyển sang Godot. Hoạt động riêng tại đây chưa port đầy đủ.")

func refresh_carried() -> void:
	if carried_model:
		carried_model.queue_free()
		carried_model = null
	if not state.carried.is_empty():
		carried_model = models.instantiate("object-" + state.carried.id, false)
		player.add_child(carried_model)
		models.fit(carried_model, 0.5)
		carried_model.position = Vector3(0.5, 1.1, 0)

func reload_room() -> void:
	var point := player.position
	enter_room(state.room_id)
	player.position = point + Vector3(0, 0.05, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index == ui_finger:
		ui_dragged = ui_dragged or event.position.distance_to(ui_origin)>12
		if ui_dragged and is_instance_valid(ui_scroll):
			ui_scroll.scroll_vertical += roundi(ui_last.y-event.position.y)
		ui_last = event.position
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == ui_finger:
		var selected: Button = ui_button
		var activate := not ui_dragged and is_instance_valid(selected) and button_at(event.position) == selected
		ui_finger = -1
		ui_button = null
		ui_scroll = null
		if activate:
			selected.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var selected := button_at(event.position)
		last_ui_input = {"x":event.position.x,"y":event.position.y,"button":selected.text if selected else ""} if map_open else {}
		if selected:
			selected.pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey:
		if picking_profile and not pin_profile_id.is_empty() and event.pressed and not event.echo:
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				press_pin(pin_profile_id, String.chr(event.keycode))
			elif event.keycode == KEY_BACKSPACE:
				press_pin(pin_profile_id, "⌫")
		keyboard[event.keycode] = event.pressed
		if event.pressed and not event.echo:
			if event.keycode == KEY_SPACE:
				jump()
			elif event.keycode == KEY_E:
				interact()
			elif event.keycode == KEY_ESCAPE:
				close_panel()
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_instance_valid(minimap) and minimap.is_visible_in_tree() and minimap.get_global_rect().has_point(event.position):
				return
			var selected := button_at(event.position)
			if selected and ui_finger == -1:
				ui_finger = event.index
				ui_button = selected
				ui_origin = event.position
				ui_last = event.position
				ui_dragged = false
				ui_scroll = null
				var parent: Node = selected.get_parent()
				while parent:
					if parent is ScrollContainer:
						ui_scroll = parent
						break
					parent = parent.get_parent()
				get_viewport().set_input_as_handled()
				return
			if not picking_profile and not loading_room and not panel.visible and look_finger == -1 and event.position.y > 100 and event.position.y < 380:
				look_finger = event.index
				look_position = event.position
				camera_touches[event.index] = event.position
			elif look_finger != -1 and camera_touches.size()<2 and not panel.visible and event.position.y > 100 and event.position.y < 380:
				camera_touches[event.index] = event.position
		elif event.index == look_finger:
			camera_touches.erase(event.index)
			look_finger = -1 if camera_touches.is_empty() else camera_touches.keys()[0]
			if look_finger != -1:
				look_position = camera_touches[look_finger]
		else:
			camera_touches.erase(event.index)
			if camera_touches.has(look_finger):
				look_position = camera_touches[look_finger]
	elif event is InputEventScreenDrag and camera_touches.has(event.index) and orbit:
		if camera_touches.size() == 2:
			var points: Array = camera_touches.values()
			var before: float = points[0].distance_to(points[1])
			camera_touches[event.index] = event.position
			points = camera_touches.values()
			var after: float = points[0].distance_to(points[1])
			if after > 1:
				orbit.zoom(before/after)
		else:
			orbit.drag(event.position-look_position)
			look_position = event.position
			camera_touches[event.index] = event.position
	elif event is InputEventMouseButton and event.pressed and orbit and not panel.visible and not picking_profile and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		orbit.zoom(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/0.9)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_looking = event.pressed and not picking_profile and not panel.visible
	elif event is InputEventMouseMotion and mouse_looking and not picking_profile and not panel.visible:
		if orbit:
			orbit.drag(event.relative)

func button_at(point: Vector2) -> Button:
	for index in range(touch_buttons.size()-1,-1,-1):
		var item: Button = touch_buttons[index]
		if not is_instance_valid(item) or not item.is_inside_tree() or not item.is_visible_in_tree() or item.disabled or not item.get_global_rect().has_point(point):
			continue
		var parent: Node = item.get_parent()
		var clipped := false
		while parent:
			if parent is Control and parent.clip_contents and not parent.get_global_rect().has_point(point):
				clipped = true
				break
			parent = parent.get_parent()
		if not clipped:
			return item
	return null

func _physics_process(delta: float) -> void:
	if loading_room:
		return
	if OS.has_feature("web") and not picking_profile:
		prepare_nearby_collisions()
	if not player:
		return
	if not picking_profile and state.room_id=="world":
		update_stream_collisions()
	if picking_profile:
		write_telemetry()
		return
	if train and train.riding:
		models.animate(avatar,"sit")
		hint.text = "CHƠI: Xuống tàu"
		return
	var axis: Vector2 = controls.axis
	if not panel.visible or map_open:
		axis += Vector2(float(keyboard.get(KEY_D, false) or keyboard.get(KEY_RIGHT, false)) - float(keyboard.get(KEY_A, false) or keyboard.get(KEY_LEFT, false)), float(keyboard.get(KEY_S, false) or keyboard.get(KEY_DOWN, false)) - float(keyboard.get(KEY_W, false) or keyboard.get(KEY_UP, false)))
	else:
		axis = Vector2.ZERO
	axis = axis.limit_length(1)
	var direction := Vector3(axis.x, 0, axis.y)
	if state.room_id == "world":
		direction = direction.rotated(Vector3.UP, camera_yaw)
		if axis.length() > 0:
			cancel_map_goal()
		elif not map_goal.is_empty() and (not panel.visible or map_open):
			var position_2d := Vector2(player.position.x,player.position.z)
			var goal := Vector2(map_goal.x,map_goal.z)
			if position_2d.distance_to(goal)<1.2:
				cancel_map_goal()
			else:
				if route_stuck>1.5:
					map_route = navigation.path(position_2d,goal)
					route_stuck = 0
				while map_route.size()>1 and position_2d.distance_to(map_route[0])<0.9:
					map_route.pop_front()
				var waypoint: Vector2 = map_route[0] if not map_route.is_empty() else goal
				var offset := waypoint-position_2d
				var factor: float = minf(1,maxf(offset.length(),3 if map_route.size()>1 else 0)/3)*(1 if position_2d.distance_to(goal)>25 else 0.75)
				direction = Vector3(offset.x,0,offset.y).normalized()*factor
				route_stuck = route_stuck+delta if actual_move_speed<0.4 else 0
	var speed := 8.0 if state.room_id == "world" else (6.5 if controls.running or keyboard.get(KEY_SHIFT, false) else 3.8)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 16 * delta
	elif player.velocity.y<0:
		player.velocity.y = 0
	var previous_transform := player.global_transform
	var grounded := player.is_on_floor() and player.velocity.y<=0
	player.move_and_slide()
	if state.room_id == "world" and grounded:
		var requested_motion := Vector3(direction.x,0,direction.z)*speed*delta
		if PlayerMotion.recover_floor_motion(player,previous_transform,requested_motion):
			floor_recoveries += 1
		elif PlayerMotion.step(player,previous_transform,requested_motion):
			step_count += 1
	var bounds: Dictionary = content.world.bounds if state.room_id == "world" else content.rooms[state.room_id].bounds
	player.position.x = clampf(player.position.x, bounds.minX, bounds.maxX)
	player.position.z = clampf(player.position.z, bounds.minZ, bounds.maxZ)
	actual_move_speed = Vector2(player.position.x-previous_transform.origin.x,player.position.z-previous_transform.origin.z).length()/maxf(delta,0.00001)
	if direction.length() > 0.05:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(direction.x, direction.z), minf(1, delta * 12))
	var motion := "idle"
	if not player.is_on_floor():
		motion = "jump"
	elif actual_move_speed > 0.3:
		motion = "carry" if not state.carried.is_empty() else ("run" if speed > 4.0 else "walk")
	models.animate(avatar, motion)
	if state.room_id == "world":
		world_lod.update(player.global_position)
	nearest = {}
	var distance := 3.2
	for target in targets:
		var current := Vector2(player.position.x, player.position.z).distance_to(Vector2(target.point.x, target.point.z))
		var reach := 3.2 if target.kind == "friend" else 2.2
		if current < minf(distance,reach) and absf(player.position.y-target.point.y)<1.5:
			nearest = target
			distance = current
	hint.text = "★ %d  ·  " % state.stars
	if not state.carried.is_empty():
		hint.text += "CHƠI để đặt đồ xuống"
	elif not nearest.is_empty():
		hint.text += "CHƠI: " + str(nearest.data.get("label", nearest.data.get("name", nearest.data.get("npc", "Khám phá"))))
	else:
		hint.text += "CHƠI: Lên tàu ở "+str(train.station_near().name) if train and not train.station_near().is_empty() else "Kéo núm trái để đi · kéo giữa màn để xoay"
	telemetry_clock += delta
	if telemetry_clock > 0.1:
		telemetry_clock = 0
		write_telemetry()

func write_telemetry() -> void:
	var path := OS.get_environment("STREAM_STATE_PATH")
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"game":"gabby-house","room":state.room_id,"profile":state.profile_id,"pickingProfile":picking_profile,"animation":models.animation_player(avatar).current_animation if models.animation_player(avatar) else "","x":player.position.x,"z":player.position.z,"y":player.position.y,"stars":state.stars,"outfit":state.outfit,"jumpCount":jump_count,"joystickX":controls.axis.x,"joystickY":controls.axis.y,"running":controls.running,"panel":panel.visible,"fps":Engine.get_frames_per_second(),"touches":get_node("/root/StreamInput").active.size() if has_node("/root/StreamInput") else 0}))

func _process(delta: float) -> void:
	if orbit and not picking_profile and not loading_room and state.room_id == "world":
		orbit.update(delta)

func _exit_tree() -> void:
	if state and OS.get_environment("GABBY_TEST") != "1":
		state.save()
