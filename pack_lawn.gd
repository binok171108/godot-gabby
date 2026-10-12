extends SceneTree

func _initialize() -> void:
	var directory: String = OS.get_cmdline_user_args()[0]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lawn-stream.json"))
	var index: Dictionary = {}
	for key in data.blocks:
		var block: Dictionary = data.blocks[key]
		var id: String = "lawn_"+key.replace(",","_")
		var path: String = directory+"/"+id+".pck"
		var packer := PCKPacker.new()
		assert(packer.pck_start(path) == OK)
		assert(packer.add_file(block.file,ProjectSettings.globalize_path(block.file)) == OK)
		assert(packer.add_file(block.scene,ProjectSettings.globalize_path(block.scene)) == OK)
		assert(packer.flush() == OK)
		var hash := FileAccess.get_sha256(path)
		var filename := id+"-"+hash.left(16)+".pck"
		DirAccess.rename_absolute(path,directory+"/"+filename)
		index[id] = {"file":"packs/"+filename,"sha256":hash,"bytes":FileAccess.get_file_as_bytes(directory+"/"+filename).size(),"label":"cỏ và hoa theo vùng","depends":["lawn"]}
	var output := FileAccess.open(directory+"/lawn-pack-index.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(index))
	output.close()
	print("LAWN_PACKS ",index.size())
	quit()
