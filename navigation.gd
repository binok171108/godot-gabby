extends RefCounted

func ready() -> bool:
	if OS.has_feature("ios"):
		return false
	return not OS.has_feature("web") or bool(JavaScriptBridge.eval("Boolean(window.gabbyNavigation?.ready)"))

func path(from: Vector2, to: Vector2) -> Array[Vector2]:
	if OS.has_feature("ios"):
		push_warning("Lõi tìm đường Node.js chưa hỗ trợ iOS; dùng joystick để di chuyển.")
		return []
	var request := {"from":[from.x,from.y],"to":[to.x,to.y]}
	var result: Array[Vector2] = []
	var output: String
	if OS.has_feature("web"):
		if not ready():
			return result
		output = str(JavaScriptBridge.eval("JSON.stringify(window.gabbyNavigation.path(%s))" % JSON.stringify(request)))
	else:
		var captured: Array = []
		var status := OS.execute("node", [ProjectSettings.globalize_path("res://navigation_cli.mjs"), ProjectSettings.globalize_path("res://data/world-map.json"), Marshalls.utf8_to_base64(JSON.stringify(request))], captured, true)
		if status != 0 or captured.is_empty():
			push_error("Không tìm được đường bằng lõi Rust gốc: "+str(captured))
			return result
		output = str(captured[0])
	var points = JSON.parse_string(output)
	if points is Array:
		for point in points:
			result.append(Vector2(point[0],point[1]))
	return result
