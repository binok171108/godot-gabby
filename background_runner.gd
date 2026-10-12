extends Node

var viewport: SubViewport
var peer := StreamPeerTCP.new()
var connected := false
var retry_at := 0
var incoming := PackedByteArray()
var pending := PackedByteArray()
var offset := 0
var streaming := false
var audio_capture: AudioEffectCapture
var frames_sent := 0
var game: Node

func _ready() -> void:
	Engine.max_fps = 60
	get_window().unfocusable = true
	get_window().position = Vector2i(-32000,-32000)
	RenderingServer.set_render_loop_enabled(false)
	var bus := AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "StreamCapture")
	AudioServer.set_bus_send(bus, "Master")
	audio_capture = AudioEffectCapture.new()
	audio_capture.buffer_length = 0.2
	AudioServer.add_bus_effect(bus,audio_capture)
	AudioServer.set_bus_mute(0,true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.size_2d_override = Vector2i(1280,720)
	viewport.size_2d_override_stretch = true
	viewport.disable_3d = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	StreamInput.target_viewport = viewport
	game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	RenderingServer.force_draw(false)
	viewport.process_mode = Node.PROCESS_MODE_DISABLED

func packet(meta: Dictionary, data: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	meta["bytes"] = data.size()
	var header := JSON.stringify(meta).to_utf8_buffer()
	var result := PackedByteArray()
	result.resize(4)
	result[0] = (header.size() >> 24) & 255
	result[1] = (header.size() >> 16) & 255
	result[2] = (header.size() >> 8) & 255
	result[3] = header.size() & 255
	result.append_array(header)
	result.append_array(data)
	return result

func flush_pending() -> void:
	if pending.is_empty():
		return
	var deadline := Time.get_ticks_usec() + 2000
	for attempt in range(8):
		var result := peer.put_partial_data(pending if offset == 0 else pending.slice(offset))
		if result[0] != OK:
			peer.disconnect_from_host()
			return
		offset += int(result[1])
		if offset >= pending.size():
			pending = PackedByteArray()
			offset = 0
			return
		if int(result[1]) == 0 or Time.get_ticks_usec() >= deadline:
			return

func send_packet(meta: Dictionary, data: PackedByteArray = PackedByteArray()) -> void:
	pending = packet(meta,data)
	offset = 0
	flush_pending()

func configure(data: Dictionary) -> void:
	StreamInput.release_all()
	var was_streaming := streaming
	streaming = bool(data.get("streaming",false))
	if streaming and not was_streaming and game.has_method("show_profiles"):
		game.show_profiles()
	var width := clampi(int(data.get("width",1920)),960,1920)
	var fps := clampi(int(data.get("fps",60)),30,60)
	viewport.size = Vector2i(width,roundi(width * 9.0 / 16.0))
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS if streaming else Node.PROCESS_MODE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if streaming else SubViewport.UPDATE_DISABLED
	Engine.max_fps = fps if streaming else 15
	audio_capture.clear_buffer()

func read_config() -> void:
	var count := peer.get_available_bytes()
	if count > 0:
		var data := peer.get_data(count)
		if data[0] == OK:
			incoming.append_array(data[1])
	while incoming.size() >= 4:
		var length := (int(incoming[0]) << 24) | (int(incoming[1]) << 16) | (int(incoming[2]) << 8) | int(incoming[3])
		if length <= 0 or length > 4096:
			peer.disconnect_from_host()
			return
		if incoming.size() < 4 + length:
			break
		var config = JSON.parse_string(incoming.slice(4,4+length).get_string_from_utf8())
		incoming = incoming.slice(4+length)
		if config is Dictionary and config.get("kind","") == "config":
			configure(config)

func _process(_delta: float) -> void:
	peer.poll()
	var status := peer.get_status()
	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		if connected:
			connected = false
			StreamInput.release_all()
			streaming = false
			viewport.process_mode = Node.PROCESS_MODE_DISABLED
			Engine.max_fps = 15
		if Time.get_ticks_msec() >= retry_at:
			retry_at = Time.get_ticks_msec() + 1000
			pending = PackedByteArray()
			incoming = PackedByteArray()
			peer.connect_to_host("127.0.0.1",8793)
		return
	if status != StreamPeerTCP.STATUS_CONNECTED:
		return
	if not connected:
		connected = true
		peer.set_no_delay(true)
		send_packet({"kind":"hello","token":OS.get_environment("STREAM_BRIDGE_TOKEN")})
	read_config()
	flush_pending()
	if not streaming or not pending.is_empty():
		return
	viewport.disable_3d = game.get("picking_profile") == true
	for i in range(4):
		if not audio_capture.can_get_buffer(960):
			break
		var samples := audio_capture.get_buffer(960)
		send_packet({"kind":"audio","rate":int(AudioServer.get_mix_rate())},samples.to_byte_array())
		if not pending.is_empty():
			return
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	if image.is_empty():
		return
	image.convert(Image.FORMAT_RGB8)
	frames_sent += 1
	var compressed := image.get_data().compress(FileAccess.COMPRESSION_ZSTD)
	send_packet({"kind":"video","width":image.get_width(),"height":image.get_height(),"format":"rgb24-zstd"},compressed)
