extends RefCounted

var content: Dictionary
var room_id := "foyer"
var outfit := "kit-pink"
var stars := 0
var discoveries: Dictionary = {}
var object_states: Dictionary = {}
var placements: Dictionary = {}
var carried: Dictionary = {}
var best_scores: Dictionary = {}
var profile_id := ""
var storage_directory := ""

func _init(data: Dictionary = {}) -> void:
	content = data

func reward(key: String, amount: int = 1) -> bool:
	if discoveries.has(key):
		return false
	discoveries[key] = true
	stars += maxi(0, amount)
	check_quests()
	return true

func record_score(game: String, score: int) -> void:
	var previous := int(best_scores.get(game, 0))
	best_scores[game] = maxi(previous, score)
	stars += maxi(0, score - previous)
	check_quests()

func check_quests() -> void:
	for quest in content.get("quests", []):
		var key: String = "quest:" + quest.id
		if discoveries.has(key):
			continue
		var completed := false
		if quest.get("kind") == "visit":
			completed = discoveries.has("visit:" + quest.place)
		elif quest.get("kind") == "meet":
			completed = not content.get("world", {}).get("friends", []).is_empty()
			for friend in content.get("world", {}).get("friends", []):
				completed = completed and discoveries.has("friend:" + friend.id)
		elif quest.has("game"):
			completed = best_scores.has(quest.game) and int(best_scores[quest.game]) >= int(quest.get("minStars", 1))
		if completed:
			discoveries[key] = true
			stars += int(quest.get("stars", 0))

func perform(object_id: String, action_id: String) -> Dictionary:
	for action in content.get("actions", {}).get(object_id, []):
		if action.id == action_id:
			var key := object_key(object_id)
			var state: Dictionary = object_states.get(key, {}).duplicate()
			state.merge(action.get("state", {}), true)
			object_states[key] = state
			reward(key + ":" + action_id)
			return action
	return {}

func object_key(object_id: String) -> String:
	for original_room in content.get("rooms", {}):
		for object in content.rooms[original_room].objects:
			if object.id == object_id:
				return original_room + ":" + object_id
	return room_id + ":" + object_id

func data_path(filename: String) -> String:
	return storage_directory + filename if not storage_directory.is_empty() else "user://" + filename

func save(path: String = "") -> void:
	if path.is_empty():
		if profile_id.is_empty():
			return
		path = data_path("progress.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify({"version":1,"room":room_id,"outfit":outfit,"stars":stars,"discoveries":discoveries,"objects":object_states,"placements":placements,"carried":carried,"bestScores":best_scores}))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)

func restore(path: String = "user://progress.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary or saved.get("version") != 1:
		return
	room_id = str(saved.get("room", "foyer"))
	if room_id != "world" and not content.get("rooms", {}).has(room_id):
		room_id = "foyer"
	outfit = str(saved.get("outfit", "kit-pink"))
	stars = maxi(0, int(saved.get("stars", 0)))
	for field in ["discoveries", "objects", "placements", "carried", "bestScores"]:
		if not saved.get(field, {}) is Dictionary:
			return
	discoveries = saved.get("discoveries", {})
	object_states = saved.get("objects", {})
	placements = saved.get("placements", {})
	carried = saved.get("carried", {})
	best_scores = saved.get("bestScores", {})
