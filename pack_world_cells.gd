extends SceneTree

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var arguments := OS.get_cmdline_user_args()
	assert(arguments.size() == 1)
	var output: String = arguments[0]
	DirAccess.make_dir_recursive_absolute(output)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world-cells.json"))
	var result: Dictionary = {}
	for key in manifest.cells:
		for state in manifest.cells[key]:
			var recipe: Dictionary = manifest.cells[key][state]
			var files: Array = recipe.get("parts",[])
			if files.is_empty():
				var config := ConfigFile.new()
				assert(config.load(recipe.path + ".import") == OK)
				var scene_path: String = config.get_value("remap", "path")
				var alias: String = recipe.path + ".remap"
				var alias_file := FileAccess.open(alias, FileAccess.WRITE)
				alias_file.store_string("[remap]\npath=\"" + scene_path + "\"\n")
				alias_file.close()
				files = [scene_path,alias]
			var id: String = "cell_" + key.replace(",", "_") + "_" + state
			var path := output.path_join(id + ".pck")
			var packer := PCKPacker.new()
			assert(packer.pck_start(path) == OK)
			for file_path in files:
				assert(packer.add_file(file_path,file_path)==OK)
			assert(packer.flush() == OK)
			var digest := FileAccess.get_sha256(path)
			var versioned := output.path_join(id + "-" + digest.left(16) + ".pck")
			assert(DirAccess.rename_absolute(path, versioned) == OK)
			var file := FileAccess.open(versioned, FileAccess.READ)
			result[id] = {"file":"packs/" + versioned.get_file(),"sha256":digest,"bytes":file.get_length(),"label":"vùng " + key + " " + state,"depends":["world_shared"]}
	var index := FileAccess.open(output.path_join("cell-pack-index.json"), FileAccess.WRITE)
	index.store_string(JSON.stringify(result))
	index.close()
	print("CELL_PACKS ", result.size())
	quit()
