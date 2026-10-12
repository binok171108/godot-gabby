extends SceneTree

const MAX_TRIANGLES := 8192
var material_cache: Dictionary = {}
var helper: Node3D
var directory := "res://assets/world-stream/prepared"
var part_number := 0
var region_bounds: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func local_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = parent.transform*result
		parent = parent.get_parent()
	return result

func material_key(material: Material) -> String:
	if not material is StandardMaterial3D:
		return str(material.get_instance_id()) if material else "none"
	var values: Array = []
	for property in material.get_property_list():
		var name: String = property.name
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or name.begins_with("resource_") or name.begins_with("metadata/") or name=="script":
			continue
		var value = material.get(name)
		if value is Resource:
			value = [value.get_class(),value.resource_path]
		values.append([name,value])
	return var_to_str(values).sha256_text()

func shared_material(material: Material) -> Material:
	if not material:
		return null
	var key := material_key(material)
	if not material_cache.has(key):
		material_cache[key] = material.duplicate(false)
	return material_cache[key]

func copy_mesh(original: Mesh, generate_lod: bool = true) -> ArrayMesh:
	var importer := ImporterMesh.from_mesh(original)
	if generate_lod:
		importer.generate_lods(25,60,[])
	var mesh := importer.get_mesh()
	for surface in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface,shared_material(original.surface_get_material(surface)))
	return mesh

func own_children(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own_children(child,owner_node)

func save_part(node: Node3D, prefix: String, paths: Array[String], collidable: bool = false) -> void:
	var part := Node3D.new()
	part.set_meta("r3f_baked",true)
	part.add_child(node)
	if collidable and node is MeshInstance3D:
		node.create_trimesh_collision()
	own_children(part,part)
	var packed := PackedScene.new()
	assert(packed.pack(part)==OK)
	var path := directory+"/"+prefix+"_"+str(part_number)+".scn"
	part_number += 1
	assert(ResourceSaver.save(packed,path)==OK)
	paths.append(path)
	var bounds: AABB = node.transform*node.get_aabb()
	region_bounds[path] = [bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z]
	part.free()

func empty_arrays(format_arrays: Array) -> Array:
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	for attribute in range(Mesh.ARRAY_MAX):
		if format_arrays[attribute] != null:
			result[attribute] = format_arrays[attribute].slice(0,0)
	return result

func flush_group(group: Dictionary, prefix: String, paths: Array[String]) -> void:
	if group.arrays[Mesh.ARRAY_VERTEX].is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,group.arrays)
	mesh.surface_set_material(0,group.material)
	var importer := ImporterMesh.from_mesh(mesh)
	if not group.ground:
		importer.generate_lods(25,60,[])
	mesh = importer.get_mesh()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.set_meta("r3f_source_name","stream-ground" if group.ground else "stream-static")
	node.set_meta("r3f_house_mesh",not group.collidable)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	save_part(node,prefix,paths,group.collidable)
	group.arrays = empty_arrays(group.arrays)

func append_surface(group: Dictionary, arrays: Array, transform: Transform3D, prefix: String, paths: Array[String]) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(vertices.size())
		for index in range(vertices.size()):
			indices[index] = index
	var normal_basis := transform.basis.inverse().transposed()
	for start in range(0,indices.size(),MAX_TRIANGLES*3):
		var end := mini(start+MAX_TRIANGLES*3,indices.size())
		if group.arrays[Mesh.ARRAY_INDEX].size()+end-start>MAX_TRIANGLES*3:
			flush_group(group,prefix,paths)
		var remap: Dictionary = {}
		for offset in range(start,end):
			var source: int = indices[offset]
			if not remap.has(source):
				remap[source] = group.arrays[Mesh.ARRAY_VERTEX].size()
				for attribute in range(Mesh.ARRAY_MAX):
					if attribute==Mesh.ARRAY_INDEX or arrays[attribute]==null:
						continue
					if attribute==Mesh.ARRAY_TANGENT:
						var tangent: Vector3 = (transform.basis*Vector3(arrays[attribute][source*4],arrays[attribute][source*4+1],arrays[attribute][source*4+2])).normalized()
						group.arrays[attribute].append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,arrays[attribute][source*4+3]]))
					else:
						var value = arrays[attribute][source]
						if attribute==Mesh.ARRAY_VERTEX:
							value = transform*value
						elif attribute==Mesh.ARRAY_NORMAL:
							value = (normal_basis*value).normalized()
						group.arrays[attribute].append(value)
			group.arrays[Mesh.ARRAY_INDEX].append(int(remap[source]))

func bake(recipe: Dictionary, prefix: String) -> void:
	part_number = 0
	region_bounds = {}
	var scene: Node3D = load(recipe.path).instantiate()
	helper.restore_source_nodes(scene,recipe.nodes)
	helper.models.restore_vertex_colors(scene)
	var instance_records: Array = []
	for record in recipe.nodes:
		if record.has("instance"):
			instance_records.append(record.instance)
	if not instance_records.is_empty():
		helper.restore_instances(scene,instance_records)
	var paths: Array[String] = []
	var groups: Dictionary = {}
	for original in helper.models.meshes(scene):
		var label: String = original.get_meta("r3f_source_name",str(original.name))
		var terrain := label.begins_with("terrain-")
		if not original.visible and not terrain:
			continue
		var collidable: bool = (terrain and label.ends_with("-lod2")) or (original.visible and not terrain and not original.get_meta("r3f_house_mesh",false) and not label.to_lower().contains("water") and not label.to_lower().contains("leaf") and not label.to_lower().contains("canopy") and not label.to_lower().contains("foliage"))
		if terrain or label.to_lower().contains("water"):
			var node := MeshInstance3D.new()
			node.mesh = copy_mesh(original.mesh,false)
			node.transform = local_transform(original,scene)
			node.visible = original.visible
			node.set_meta("r3f_source_name",label)
			save_part(node,prefix,paths,collidable)
			continue
		for surface in range(original.mesh.get_surface_count()):
			var arrays: Array = original.mesh.surface_get_arrays(surface)
			var material: Material = shared_material(original.mesh.surface_get_material(surface))
			var bounds: AABB = local_transform(original,scene)*original.get_aabb()
			var ground := bounds.size.y<0.4 and maxf(bounds.size.x,bounds.size.z)>2.0
			var key := str(collidable)+"|"+str(ground)+"|"+material_key(material)+"|"+str(original.mesh.surface_get_format(surface))
			if not groups.has(key):
				groups[key] = {"arrays":empty_arrays(arrays),"material":material,"collidable":collidable,"ground":ground}
			append_surface(groups[key],arrays,local_transform(original,scene),prefix,paths)
	for group in groups.values():
		flush_group(group,prefix,paths)
	for original in scene.find_children("*","MultiMeshInstance3D",true,false):
		var node := MultiMeshInstance3D.new()
		node.multimesh = original.multimesh.duplicate(false)
		var source_name: String = original.get_meta("r3f_source_name",str(original.name))
		var ground := source_name.begins_with("road-")
		node.set_meta("r3f_source_name","stream-ground" if ground else source_name)
		node.multimesh.mesh = copy_mesh(original.multimesh.mesh,not ground)
		var bounds := AABB()
		for index in range(node.multimesh.instance_count):
			var instance_bounds: AABB = node.multimesh.get_instance_transform(index)*node.multimesh.mesh.get_aabb()
			bounds = instance_bounds if index==0 else bounds.merge(instance_bounds)
		node.multimesh.custom_aabb = bounds.grow(0.01)
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		node.transform = local_transform(original,scene)
		node.visible = original.visible
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		save_part(node,prefix,paths)
	scene.free()
	recipe["parts"] = paths
	recipe["regions"] = region_bounds.duplicate()
	print("BAKED ",prefix," ",paths.size()," parts")

func build() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	helper = load("res://main.gd").new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world-cells.json"))
	bake(manifest.base,"base")
	for key in manifest.cells:
		for state in manifest.cells[key]:
			bake(manifest.cells[key][state],key.replace(",","_")+"_"+state)
	var file := FileAccess.open("res://data/world-cells.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	helper.free()
	quit()
