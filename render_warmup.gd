extends RefCounted

static func prepare(game: Node3D) -> void:
	var original: Transform3D = game.camera.global_transform
	var warm_nodes := Node3D.new()
	game.scenery.add_child(warm_nodes)
	if is_instance_valid(game.tree_forest):
		var forest: Node3D = game.tree_forest
		var image := Image.create_from_data(1,1,false,Image.FORMAT_RGBAF,PackedFloat32Array([0,0,0,1]).to_byte_array())
		var texture := ImageTexture.create_from_image(image)
		for id in forest.templates:
			for level in forest.templates[id]:
				for template in forest.templates[id][level]:
					var node := MultiMeshInstance3D.new()
					node.multimesh = MultiMesh.new()
					node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
					node.multimesh.use_colors = true
					node.multimesh.use_custom_data = true
					node.multimesh.mesh = template.mesh
					node.multimesh.instance_count = 1
					node.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.2),Vector3.ZERO))
					node.multimesh.set_instance_color(0,Color.WHITE)
					node.multimesh.set_instance_custom_data(0,Color(0,0,0,1))
					node.material_override = forest.material(id,template.leaf,texture)
					warm_nodes.add_child(node)
					node.global_position = game.player.global_position
	game.models.animate(game.avatar,"run")
	for index in range(8):
		var angle := float(index)*TAU/8
		game.camera.global_position = game.player.global_position+Vector3(sin(angle)*11,5.8,cos(angle)*11)
		game.camera.look_at(game.player.global_position+Vector3(0,1.7,0))
		game.world_lod.update(game.player.global_position)
		if is_instance_valid(game.tree_forest):
			game.tree_forest.update_forest(true)
		game.web_loading("Đang chuẩn bị đồ họa trước khi chơi…",index+1,8)
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
	warm_nodes.get_parent().remove_child(warm_nodes)
	warm_nodes.queue_free()
	game.camera.global_transform = original
	game.world_lod.update(game.player.global_position)
	if is_instance_valid(game.tree_forest):
		game.tree_forest.update_forest(true)
	game.models.animate(game.avatar,"idle")
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
