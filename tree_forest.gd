extends Node3D

const Policy = preload("res://world_stream_policy.gd")

var data: Dictionary
var host: Node
var templates: Dictionary = {}
var batches: Dictionary = {}
var levels := PackedInt32Array()
var last_focus := Vector3(INF, INF, INF)
var last_update := -1000000
var stats := {"visible":0,"lod":[0,0,0],"draws":0}
var buffer_updates := 0

func initialize(game: Node) -> void:
	host = game
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/tree-kit.json"))
	host.streaming.register_provider(self)
	levels.resize(data.type.size())
	update_forest(true)

func ensure_template(id: String) -> void:
	if templates.has(id):
		return
	var packed: PackedScene = load("res://assets/tree-kit/models/" + id + ".glb")
	var root: Node3D = packed.instantiate()
	var variants: Dictionary = {}
	for mesh: MeshInstance3D in host.models.meshes(root):
		var suffix: PackedStringArray = str(mesh.name).split("_LOD")
		if suffix.size() < 2:
			continue
		var level: int = int(suffix[1].left(1))
		if not variants.has(level):
			variants[level] = []
		variants[level].append({"mesh":mesh.mesh,"leaf":str(mesh.name).ends_with("_Leaf")})
	templates[id] = variants
	root.free()

func material(id: String, is_leaf: bool, origin_texture: ImageTexture) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://tree_kit.gdshader")
	var group: String = data.groups[id] if is_leaf else "bark"
	result.set_shader_parameter("atlas", load("res://assets/tree-kit/textures/" + group + ".png"))
	result.set_shader_parameter("origins", origin_texture)
	result.set_shader_parameter("leaf", is_leaf)
	result.set_shader_parameter("cutoff", data.alphaCutoff)
	result.set_shader_parameter("palette_count", data.palettes.index.size())
	var stops: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array(),PackedVector3Array()]
	var strengths := PackedFloat32Array()
	for index in range(16):
		var palette: Dictionary = data.palettes.palettes[data.palettes.index[mini(index, data.palettes.index.size()-1)]]
		strengths.append(palette.strength)
		for stop in range(3):
			var color := Color(palette.stops[stop][0], palette.stops[stop][1], palette.stops[stop][2]).srgb_to_linear()
			stops[stop].append(Vector3(color.r, color.g, color.b))
	result.set_shader_parameter("palette_a", stops[0])
	result.set_shader_parameter("palette_b", stops[1])
	result.set_shader_parameter("palette_c", stops[2])
	result.set_shader_parameter("palette_strength", strengths)
	result.set_shader_parameter("alpha_scale", PackedFloat32Array(data.alphaScale[group]) if is_leaf else PackedFloat32Array([1,1,1,1,1,1,1,1,1,1,1,1]))
	for parameter in ["strength","speed","flutter","direction"]:
		result.set_shader_parameter("wind_"+parameter if parameter != "flutter" else "flutter", Vector2(data.wind.direction[0],data.wind.direction[1]) if parameter == "direction" else data.wind[parameter])
	return result

func update_forest(force: bool = false) -> void:
	var position := Vector3(host.streaming.focus.x,0,host.streaming.focus.y)
	var preset: Dictionary = data.preset
	if not force and position.distance_squared_to(last_focus)<Policy.MOVE_THRESHOLD*Policy.MOVE_THRESHOLD:
		return
	last_update = Time.get_ticks_msec()
	last_focus = position
	var selected: Dictionary = {}
	stats = {"visible":0,"lod":[0,0,0],"draws":0}
	for index in range(data.type.size()):
		var center := Vector3(data.cx[index],data.cy[index],data.cz[index])
		var extent := Vector2.ONE*float(data.radius[index])
		var bounds := Rect2(Vector2(center.x,center.z)-extent,extent*2)
		if not host.streaming.should_load(bounds):
			continue
		var state: String = Policy.state(bounds,host.streaming.focus)
		var level := 0 if state=="near" else (1 if state=="lod" else 2)
		levels[index] = level
		if state!="off":
			stats.visible += 1
			stats.lod[level] += 1
		var chunk: float = Policy.CELL_SIZE
		var key := "%d|%d|%d|%d" % [data.type[index],level,floori(data.pos[index*3]/chunk),floori(data.pos[index*3+2]/chunk)]
		if not selected.has(key):
			selected[key] = []
		selected[key].append(index)
	for key in batches:
		for node in batches[key].nodes:
			if not selected.has(key):
				host.streaming.unregister_visuals(node)
			if node.visible != selected.has(key):
				node.visible = selected.has(key)
	for key in selected:
		var members: Array = selected[key]
		var fields: PackedStringArray = key.split("|")
		var id: String = data.ids[int(fields[0])]
		ensure_template(id)
		var level := int(fields[1])
		if batches.has(key) and batches[key].members == members:
			update_shadows(batches[key],position,preset,level)
			for node in batches[key].nodes:
				node.visible = true
				host.streaming.register_visuals(node)
			stats.draws += batches[key].nodes.size()
			continue
		var origins := PackedFloat32Array()
		var transforms := PackedFloat32Array()
		var center := Vector2.ZERO
		for index in members:
			var matrix: Array = data.matrix.slice(index*16,index*16+16)
			transforms.append_array(PackedFloat32Array([matrix[0],matrix[4],matrix[8],matrix[12],matrix[1],matrix[5],matrix[9],matrix[13],matrix[2],matrix[6],matrix[10],matrix[14]]))
			transforms.append_array(PackedFloat32Array([1,1,1,1]))
			transforms.append_array(PackedFloat32Array(data.tint.slice(index*4,index*4+4)))
			origins.append_array(PackedFloat32Array(data.orig.slice(index*4,index*4+4)))
			center += Vector2(data.pos[index*3],data.pos[index*3+2])
		var origin_image := Image.create_from_data(members.size(),1,false,Image.FORMAT_RGBAF,origins.to_byte_array())
		var origin_texture := ImageTexture.create_from_image(origin_image)
		if not batches.has(key):
			var nodes: Array[MultiMeshInstance3D] = []
			for template in templates[id][level]:
				var node := MultiMeshInstance3D.new()
				node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
				node.multimesh = MultiMesh.new()
				node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				node.multimesh.use_colors = true
				node.multimesh.use_custom_data = true
				node.multimesh.mesh = template.mesh
				node.material_override = material(id,template.leaf,origin_texture)
				add_child(node)
				nodes.append(node)
			batches[key] = {"nodes":nodes,"members":[],"center":Vector2.ZERO,"bounds":Rect2()}
		batches[key].members = members.duplicate()
		buffer_updates += 1
		center /= members.size()
		batches[key].center = center
		for node in batches[key].nodes:
			node.multimesh.instance_count = members.size()
			node.multimesh.buffer = transforms
			var bounds := AABB()
			for index in range(node.multimesh.instance_count):
				var instance_bounds: AABB = node.multimesh.get_instance_transform(index)*node.multimesh.mesh.get_aabb()
				bounds = instance_bounds if index==0 else bounds.merge(instance_bounds)
			node.multimesh.custom_aabb = bounds.grow(0.15)
			var region := Policy.horizontal_bounds(bounds)
			batches[key].bounds = region if node==batches[key].nodes[0] else batches[key].bounds.merge(region)
			RenderingServer.multimesh_set_physics_interpolated(node.multimesh.get_rid(),false)
			node.multimesh.reset_instances_physics_interpolation()
			node.material_override.set_shader_parameter("origins", origin_texture)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if preset.shadow.enabled and level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = true
			stats.draws += 1
			host.streaming.register_visuals(node)
		update_shadows(batches[key],position,preset,level)
	for key in batches.keys():
		if not selected.has(key) and not host.streaming.should_retain(batches[key].bounds):
			for node in batches[key].nodes:
				node.queue_free()
			batches.erase(key)
	var retained_types: Dictionary = {}
	for key: String in batches:
		retained_types[data.ids[int(key.split("|")[0])]] = true
	for id: String in templates.keys():
		if not retained_types.has(id):
			templates.erase(id)

func update_shadows(batch: Dictionary, position: Vector3, preset: Dictionary, level: int) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if preset.shadow.enabled and level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in batch.nodes:
		if node.cast_shadow != mode:
			node.cast_shadow = mode

func _process(_delta: float) -> void:
	if not get_meta("streaming_managed",false) and is_instance_valid(host) and not host.picking_profile and not host.loading_room:
		update_forest()

func stream_update() -> void:
	update_forest()
