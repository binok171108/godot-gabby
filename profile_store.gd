extends RefCounted

const State = preload("res://game_state.gd")
var content: Dictionary
var directory: String

func _init(data: Dictionary, base_directory: String = "") -> void:
	content = data
	directory = base_directory if not base_directory.is_empty() else ("user://qa-profiles/" if OS.get_environment("GABBY_TEST") == "1" else "user://profiles/")
	if base_directory.is_empty() and OS.get_environment("GABBY_TEST") == "1" and not OS.get_environment("GABBY_QA_RUN_ID").is_empty():
		directory += OS.get_environment("GABBY_QA_RUN_ID") + "/"

func definition(id: String) -> Dictionary:
	for profile in content.get("profiles", []):
		if profile.id == id:
			return profile
	return {}

func accepts(id: String, pin: String = "") -> bool:
	var profile := definition(id)
	return not profile.is_empty() and (not profile.has("pin") or str(profile.pin) == pin)

func load_profile(id: String, pin: String = "") -> RefCounted:
	if not accepts(id, pin):
		return null
	var state := State.new(content)
	state.profile_id = id
	state.storage_directory = directory + id + "/"
	DirAccess.make_dir_recursive_absolute(state.storage_directory)
	var path: String = state.data_path("progress.json")
	if directory == "user://profiles/" and id == "com":
		for filename in ["progress.json", "drawing.json"]:
			var destination: String = state.data_path(filename)
			if not FileAccess.file_exists(destination) and FileAccess.file_exists("user://" + filename):
				DirAccess.copy_absolute("user://" + filename, destination)
	state.room_id = "foyer" if OS.get_environment("GABBY_TEST") == "1" else "world"
	state.restore(path)
	return state
