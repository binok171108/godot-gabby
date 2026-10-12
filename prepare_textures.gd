extends SceneTree

var changed := 0

func _initialize() -> void:
	prepare_directory("res://assets")
	print("TEXTURE_IMPORTS ",changed," 3D textures: lossless mipmaps, original resolution")
	quit()

func prepare_directory(path: String) -> void:
	if path == "res://assets/world-map":
		return
	var directory := DirAccess.open(path)
	if not directory:
		return
	for name in directory.get_directories():
		prepare_directory(path+"/"+name)
	for name in directory.get_files():
		if not name.ends_with(".import"):
			continue
		var configuration := ConfigFile.new()
		var file := path+"/"+name
		if configuration.load(file) != OK or configuration.get_value("remap","importer","") != "texture":
			continue
		var mode := 0
		if configuration.get_value("params","compress/mode",0) == mode and configuration.get_value("params","mipmaps/generate",false):
			continue
		configuration.set_value("params","compress/mode",mode)
		configuration.set_value("params","compress/high_quality",true)
		configuration.set_value("params","compress/uastc_level",4)
		configuration.set_value("params","compress/rdo_quality_loss",0.0)
		configuration.set_value("params","mipmaps/generate",true)
		configuration.set_value("params","process/size_limit",0)
		configuration.save(file)
		changed += 1
