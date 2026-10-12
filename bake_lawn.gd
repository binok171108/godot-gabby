extends SceneTree

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lawn-stream.json"))
	var library: Node3D = load("res://assets/lawn-stream/lawn-kit.glb").instantiate()
	var templates: Dictionary = {}
	for node in library.find_children("*","MeshInstance3D",true,false):
		templates[str(node.name)] = node.mesh.surface_get_arrays(0)
	DirAccess.make_dir_recursive_absolute("res://assets/lawn-stream/prepared")
	for key in data.blocks:
		var values := FileAccess.get_file_as_bytes(data.blocks[key].file).to_float32_array()
		var fields: PackedStringArray = key.split(",")
		var origin := Vector3(float(fields[0])*data.size,0,float(fields[1])*data.size)
		var groups: Dictionary = {}
		for offset in range(0,values.size(),11):
			var asset: String = data.names[int(values[offset])]
			var variant := asset.unicode_at(asset.length()-1)-65
			if variant>=2:
				asset = asset.left(asset.length()-1)+String.chr(65+variant%2)
			var decal := asset.begins_with("DirtPatch")
			var template := asset+("_LOD0" if decal else "_LOD2")
			assert(templates.has(template),"Thiếu geometry cỏ: "+template)
			var group_name := "decal" if decal else "grass"
			if not groups.has(group_name):
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
				arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
				arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
				arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
				arrays[Mesh.ARRAY_COLOR] = PackedColorArray()
				arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
				groups[group_name] = arrays
			var destination: Array = groups[group_name]
			var source: Array = templates[template]
			var basis := Basis(Vector3.UP,values[offset+4]).scaled(Vector3.ONE*values[offset+5])
			var transform := Transform3D(basis,Vector3(values[offset+1],values[offset+2],values[offset+3])-origin)
			var first: int = destination[Mesh.ARRAY_VERTEX].size()
			var color := Color(values[offset+6],values[offset+7],values[offset+8],1)
			for index in range(source[Mesh.ARRAY_VERTEX].size()):
				destination[Mesh.ARRAY_VERTEX].append(transform*source[Mesh.ARRAY_VERTEX][index])
				destination[Mesh.ARRAY_NORMAL].append((basis*source[Mesh.ARRAY_NORMAL][index]).normalized())
				destination[Mesh.ARRAY_TEX_UV].append(source[Mesh.ARRAY_TEX_UV][index])
				destination[Mesh.ARRAY_TEX_UV2].append(source[Mesh.ARRAY_TEX_UV2][index] if source[Mesh.ARRAY_TEX_UV2]!=null else Vector2.ZERO)
				destination[Mesh.ARRAY_COLOR].append(color)
			var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in range(source[Mesh.ARRAY_VERTEX].size()):
					destination[Mesh.ARRAY_INDEX].append(first+index)
			else:
				for index in indices:
					destination[Mesh.ARRAY_INDEX].append(first+index)
		var root := Node3D.new()
		root.position = origin
		root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		for group_name in groups:
			var node := MeshInstance3D.new()
			node.name = group_name
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,groups[group_name])
			node.mesh = mesh
			node.custom_aabb = mesh.get_aabb().grow(0.15)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = 64.0
			node.visibility_range_end_margin = 8.0
			node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			root.add_child(node)
			node.owner = root
		var packed := PackedScene.new()
		var error := packed.pack(root)
		assert(error==OK)
		var path: String = "res://assets/lawn-stream/prepared/lawn_"+key.replace(",","_")+".scn"
		error = ResourceSaver.save(packed,path)
		assert(error==OK)
		data.blocks[key]["scene"] = path
		root.free()
	var output := FileAccess.open("res://data/lawn-stream.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(data))
	output.close()
	library.free()
	print("BAKED_LAWN ",data.blocks.size()," ô cố định, tối đa hai lượt vẽ mỗi ô")
	quit()
