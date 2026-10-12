extends Node3D

const Policy = preload("res://world_stream_policy.gd")
var host: Node
var data: Dictionary
var materials: Dictionary = {}
var blocks: Dictionary = {}
var busy := false
var last_position := Vector2(INF,INF)
var requests := 0
var unloads := 0
var updates := 0
var instances := 0

func block_distance(key: String, position: Vector2) -> float:
	return Policy.distance(block_bounds(key),position)

func block_bounds(key: String) -> Rect2:
	var fields := key.split(",")
	return Rect2(Vector2(float(fields[0])*data.size,float(fields[1])*data.size),Vector2.ONE*data.size)

func initialize(game: Node) -> void:
	host = game
	host.streaming.register_provider(self)
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/lawn-stream.json"))
	if not await AssetPacks.ensure_pack("lawn"):
		return
	var library: Node3D = load("res://assets/lawn-stream/lawn-kit.glb").instantiate()
	var image := Image.create_from_data(1024,1024,false,Image.FORMAT_R8,FileAccess.get_file_as_bytes("res://data/foliage-blocked.bin"))
	var blocked_texture := ImageTexture.create_from_image(image)
	for mesh in host.models.meshes(library):
		var category := "decal" if str(mesh.name).begins_with("DirtPatch") else "grass"
		if materials.has(category):
			continue
		var original: StandardMaterial3D = mesh.mesh.surface_get_material(0)
		var material := ShaderMaterial.new()
		material.shader = load("res://grass_decal.gdshader" if category=="decal" else "res://grass.gdshader")
		material.set_shader_parameter("base_texture",original.albedo_texture)
		material.set_shader_parameter("blocked_map",blocked_texture)
		material.set_shader_parameter("has_blocked_map",true)
		materials[category] = material
	library.free()
	await refresh(true)

func cache_wanted(key: String) -> bool:
	return host.streaming.should_load(block_bounds(key))

func refresh(initial: bool = false) -> void:
	if busy:
		return
	var position: Vector2 = host.streaming.focus
	if not initial and position.distance_to(last_position)<Policy.MOVE_THRESHOLD:
		return
	busy = true
	var requested_position := position
	for key in blocks.keys():
		if host.streaming.should_retain(block_bounds(key)):
			continue
		var node: Node3D = blocks[key]
		remove_child(node)
		node.queue_free()
		instances -= int(data.blocks[key].count)
		blocks.erase(key)
		unloads += 1
	var order: Array = []
	for key in data.blocks:
		if cache_wanted(key) and not blocks.has(key):
			order.append({"key":key,"distance":minf(block_distance(key,position),block_distance(key,host.streaming.predicted))})
	order.sort_custom(func(first,second): return first.distance<second.distance)
	for entry in order:
		if not cache_wanted(entry.key):
			continue
		var fields: PackedStringArray = entry.key.split(",")
		var point := Vector2((float(fields[0])+0.5)*data.size,(float(fields[1])+0.5)*data.size)
		if not await host.streaming.request_pack("lawn_"+entry.key.replace(",","_"),point,initial):
			busy = false
			return
		if not cache_wanted(entry.key):
			continue
		var started := Time.get_ticks_usec()
		var packed: PackedScene = ResourceLoader.load(data.blocks[entry.key].scene,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		if not packed:
			busy = false
			return
		var node: Node3D = packed.instantiate()
		for mesh in host.models.meshes(node):
			mesh.material_override = materials[str(mesh.name)]
		add_child(node)
		host.streaming.register_visuals(node)
		blocks[entry.key] = node
		instances += int(data.blocks[entry.key].count)
		requests += 1
		await host.streaming.checkpoint(Time.get_ticks_usec()-started)
	last_position = requested_position
	updates += 1
	busy = false

func stream_update() -> void:
	refresh()

func info() -> Dictionary:
	return {"blocks":blocks.size(),"renderedBlocks":blocks.size(),"instances":instances,"requests":requests,"unloads":unloads,"updates":updates,"radius":Policy.ACTIVE_RADIUS,"busy":busy,"bufferUploads":0,"batches":blocks.size()*2,"rendering":"native-spatial-meshes"}
