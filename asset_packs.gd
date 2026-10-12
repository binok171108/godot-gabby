extends Node
const Codec = preload("res://asset_codec.gd")

var manifest: Dictionary = {}
var mounted: Dictionary = {}
var failed_message := ""
var active_request: HTTPRequest
var active_label := ""
var progress_clock := 0.0
var active_foreground := true
var max_decode_usec := 0
var max_mount_usec := 0
signal pack_completed
signal slot_available
var in_flight: Dictionary = {}
var results: Dictionary = {}
var queue: Array[Dictionary] = []
var transfers := 0
const MAX_TRANSFERS := 3

func _process(delta: float) -> void:
	progress_clock += delta
	if progress_clock < 0.2 or not is_instance_valid(active_request) or not active_foreground:
		return
	progress_clock = 0
	var message := "Đang tải %s — đã nhận %.1f MB" % [active_label, active_request.get_downloaded_bytes() / 1000000.0]
	JavaScriptBridge.eval("window.gabbyLoadStatus(%s,0,0)" % JSON.stringify(message))

func ensure_pack(id: String, foreground: bool = true, priority: float = 0.0) -> bool:
	if not OS.has_feature("web") or mounted.has(id):
		return true
	if in_flight.has(id):
		while in_flight.has(id):
			await pack_completed
		return results.get(id,false)
	in_flight[id] = true
	var success: bool = await load_pack(id,foreground,priority)
	results[id] = success
	in_flight.erase(id)
	pack_completed.emit()
	return success

func load_pack(id: String, foreground: bool, priority: float) -> bool:
	if not OS.has_feature("web") or mounted.has(id):
		return true
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/web-packs.json"))
	if not manifest.has(id):
		return fail_pack("Không tìm thấy gói tài nguyên: " + id, foreground)
	var entry: Dictionary = manifest[id]
	for dependency in entry.get("depends", []):
		if not await ensure_pack(dependency, foreground,priority):
			return false
	DirAccess.make_dir_recursive_absolute("user://asset-packs")
	var path := "user://asset-packs/" + str(entry.get("cache_file",entry.file)).get_file()
	if FileAccess.file_exists(path) and ProjectSettings.load_resource_pack(path):
		mounted[id] = true
		return true
	var ticket := {"id":id,"priority":-1000.0 if foreground else priority}
	queue.append(ticket)
	while true:
		queue.sort_custom(func(first,second): return first.priority<second.priority)
		if transfers<MAX_TRANSFERS and queue[0].id==id:
			queue.pop_front()
			transfers += 1
			break
		await slot_available
	var success: bool = await download_pack(id,entry,path,foreground)
	transfers -= 1
	slot_available.emit()
	return success

func download_pack(id: String, entry: Dictionary, path: String, foreground: bool) -> bool:
	var request := HTTPRequest.new()
	request.accept_gzip = false
	request.download_chunk_size = 1048576
	request.timeout = 180
	add_child(request)
	active_request = request
	active_label = str(entry.label)
	active_foreground = foreground
	var url := str(JavaScriptBridge.eval("new URL(%s, location.href).href" % JSON.stringify(entry.file)))
	if foreground:
		JavaScriptBridge.eval("window.gabbyLoadStatus(%s,0,0)" % JSON.stringify("Đang tải " + str(entry.label) + "…"))
	var error := request.request(url)
	if error != OK:
		request.queue_free()
		return fail_pack("Không bắt đầu tải được gói " + id + ": " + str(error), foreground)
	var result: Array = await request.request_completed
	active_request = null
	request.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return fail_pack("Tải gói " + id + " thất bại: HTTP " + str(result[1]) + ", mã " + str(result[0]), foreground)
	var payload: PackedByteArray = result[3]
	if entry.get("codec","") == "zstd":
		if payload.size() != int(entry.wire_bytes) or Codec.sha256(payload) != entry.wire_sha256:
			return fail_pack("Gói nén bị thiếu hoặc sai dữ liệu: "+id,foreground)
		if foreground:
			JavaScriptBridge.eval("window.gabbyLoadStatus(%s,0,0)" % JSON.stringify("Đang giải nén "+str(entry.label)+"…"))
			await get_tree().process_frame
		var started := Time.get_ticks_usec()
		var decoded := payload.decompress(int(entry.bytes),FileAccess.COMPRESSION_ZSTD)
		max_decode_usec = maxi(max_decode_usec,Time.get_ticks_usec()-started)
		result.clear()
		payload = decoded
	if payload.size() != int(entry.bytes):
		return fail_pack("Gói %s nhận thiếu dữ liệu: %d/%d byte" % [id, payload.size(), entry.bytes], foreground)
	var output := FileAccess.open(path + ".part", FileAccess.WRITE)
	if not output:
		return fail_pack("Không lưu được gói tài nguyên: " + id, foreground)
	output.store_buffer(payload)
	output.close()
	payload = PackedByteArray()
	result.clear()
	if foreground:
		JavaScriptBridge.eval("window.gabbyLoadStatus(%s,0,0)" % JSON.stringify("Đang kiểm tra và mở gói " + str(entry.label) + "…"))
	await get_tree().process_frame
	if FileAccess.get_sha256(path + ".part") != entry.sha256:
		var downloaded := FileAccess.open(path + ".part", FileAccess.READ)
		var downloaded_size := downloaded.get_length() if downloaded else -1
		return fail_pack("Gói " + id + " không đầy đủ hoặc sai phiên bản: %d/%d byte, SHA %s. Hãy tải lại." % [downloaded_size, entry.bytes, FileAccess.get_sha256(path + ".part")], foreground)
	var started := Time.get_ticks_usec()
	if DirAccess.rename_absolute(path + ".part", path) != OK or not ProjectSettings.load_resource_pack(path):
		return fail_pack("Không mở được gói tài nguyên: " + id, foreground)
	max_mount_usec = maxi(max_mount_usec,Time.get_ticks_usec()-started)
	mounted[id] = true
	return true

func fail_pack(message: String, foreground: bool = true) -> bool:
	failed_message = message
	push_error(message)
	if foreground:
		JavaScriptBridge.eval("fail(%s)" % JSON.stringify(message))
	return false
