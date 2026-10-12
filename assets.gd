extends RefCounted

const Policy = preload("res://world_stream_policy.gd")

var cache: Dictionary = {}
var required_ai := PackedStringArray()

func scene_template(original: Node3D) -> PackedScene:
	var node: Node3D = original.duplicate()
	own_template_children(node,node)
	var packed := PackedScene.new()
	var error := packed.pack(node)
	if error!=OK:
		push_error("Không tạo được template model: "+str(error))
	assert(error==OK)
	node.free()
	return packed

func own_template_children(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own_template_children(child,owner_node)

func update_render_range(model: Node3D, focus: Vector3, shadow_radius: float = Policy.DETAIL_RADIUS) -> void:
	if not model.has_meta("render_meshes"):
		model.set_meta("render_meshes",meshes(model))
	for mesh in model.get_meta("render_meshes"):
		var center: Vector3 = mesh.global_transform*mesh.get_aabb().get_center()
		var distance := Vector2(center.x-focus.x,center.z-focus.z).length()
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if distance<=shadow_radius else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.cast_shadow!=mode:
			mesh.cast_shadow = mode
		if mesh.visibility_range_end!=0.0:
			mesh.visibility_range_end = 0.0

func instantiate(asset: String, prefer_ai: bool = true) -> Node3D:
	var path := "res://assets/" + asset + ".glb"
	if required_ai.has(asset):
		path = "res://assets/ai/" + asset + ".glb"
	if prefer_ai and ResourceLoader.exists("res://assets/ai/" + asset + ".glb"):
		path = "res://assets/ai/" + asset + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Thiếu asset: " + path)
		return Node3D.new()
	if not cache.has(path):
		cache[path] = load(path)
	var model: Node3D = cache[path].instantiate()
	model.set_meta("asset_path", path)
	restore_vertex_colors(model)
	return model

func restore_vertex_colors(model: Node3D) -> void:
	for mesh in meshes(model):
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D and (mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false

func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for mesh in meshes(root):
		var local := root.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		result = result.merge(box) if initialized else box
		initialized = true
	return result

func meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		result.append_array(meshes(child))
	return result

func fit(root: Node3D, height: float) -> void:
	var box := bounds(root)
	if box.size.y > 0.01:
		root.scale *= height / box.size.y
		root.position.y -= box.position.y * root.scale.y

func set_look(root: Node3D, look: String) -> void:
	var looks: Array[String] = []
	for mesh in meshes(root):
		var label := str(mesh.name)
		if not label.begins_with("com_") and label.contains("_"):
			var prefix := label.get_slice("_", 0)
			if not looks.has(prefix):
				looks.append(prefix)
	looks.sort()
	var mask := pow(2.0, looks.find(look)) if looks.has(look) else 0.0
	for mesh in meshes(root):
		var label := str(mesh.name)
		if label.begins_with("com_"):
			mesh.visible = true
			for surface in range(mesh.mesh.get_surface_count()):
				var original = mesh.mesh.surface_get_material(surface)
				if not original is StandardMaterial3D:
					continue
				var material := ShaderMaterial.new()
				var shader := Shader.new()
				shader.code = "shader_type spatial; render_mode cull_disabled; uniform float mask_bit; uniform vec4 tint: source_color; uniform sampler2D color_map: source_color, filter_linear_mipmap; uniform bool has_map; varying float skin_mask; void vertex(){skin_mask=UV2.x;} void fragment(){if(mask_bit>0.5 && mod(floor(floor(skin_mask+0.5)/mask_bit),2.0)>0.5){discard;} vec4 base=tint; if(has_map){base*=texture(color_map,UV);} ALBEDO=base.rgb; ROUGHNESS=0.85;}"
				material.shader = shader
				material.set_shader_parameter("mask_bit", mask)
				material.set_shader_parameter("tint", original.albedo_color)
				material.set_shader_parameter("has_map", original.albedo_texture != null)
				if original.albedo_texture:
					material.set_shader_parameter("color_map", original.albedo_texture)
				mesh.set_surface_override_material(surface, material)
		else:
			mesh.visible = label.begins_with(look + "_")

func animation_player(root: Node) -> AnimationPlayer:
	if root.has_meta("animation_player"):
		var cached = root.get_meta("animation_player")
		if is_instance_valid(cached):
			return cached
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := animation_player(child)
		if found:
			root.set_meta("animation_player", found)
			return found
	return null

func select_clip(available: PackedStringArray, motion: String) -> String:
	var candidates: Array = {"idle":["idle","idle-ual"],"walk":["walk","walk-ual"],"carry":["carry-walk","walk","walk-ual"],"run":["jog","run","walk"],"jump":["jump-air","jump-start"],"sit":["sit-idle","sit"],"climb":["climb"]}.get(motion, [motion])
	for candidate in candidates:
		for clip in available:
			if clip.get_slice("/", clip.get_slice_count("/") - 1).to_lower() == candidate:
				return clip
	return ""

func animate(root: Node, keyword: String) -> void:
	var player := animation_player(root)
	if not player:
		return
	if not root.has_meta("animation_clips"):
		root.set_meta("animation_clips", {})
	var clips: Dictionary = root.get_meta("animation_clips")
	if not clips.has(keyword):
		clips[keyword] = select_clip(player.get_animation_list(), keyword)
	var clip: String = clips[keyword]
	if not clip.is_empty() and player.current_animation != clip:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.play(clip, 0.15)
