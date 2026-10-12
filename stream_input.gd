extends Node
var socket := PacketPeerUDP.new()
var secret := ""
var active: Dictionary = {}
var last_sequence := -1
var instance := ""
var last_packet := 0
var target_viewport: SubViewport
var remote_keycodes: Dictionary = {}
var mouse_buttons: Dictionary = {}
var mouse_position := Vector2(640,360)

func _ready() -> void:
	secret = OS.get_environment("STREAM_BRIDGE_TOKEN")
	if secret.is_empty():
		set_process(false)
		return
	var result := socket.bind(8792,"127.0.0.1")
	if result != OK:
		push_error("Cannot bind stream input: " + str(result))
		set_process(false)
	if OS.get_environment("STREAM_BACKGROUND") != "1":
		get_window().focus_exited.connect(release_all)

func deliver(event: InputEvent) -> void:
	if target_viewport:
		target_viewport.push_input(event,true)
	else:
		Input.parse_input_event(event)

func touch_event(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	deliver(event)

func key_code(key: String) -> int:
	var special := {"space":KEY_SPACE,"enter":KEY_ENTER,"esc":KEY_ESCAPE,"tab":KEY_TAB,"shift":KEY_SHIFT,"ctrl":KEY_CTRL,"alt":KEY_ALT,"up":KEY_UP,"down":KEY_DOWN,"left":KEY_LEFT,"right":KEY_RIGHT,"backspace":KEY_BACKSPACE}
	if special.has(key):
		return special[key]
	if key.length() == 1:
		return key.to_upper().unicode_at(0)
	return 0

func key_event(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	deliver(event)

func button_event(name: String, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = {"left":MOUSE_BUTTON_LEFT,"right":MOUSE_BUTTON_RIGHT,"middle":MOUSE_BUTTON_MIDDLE}.get(name,MOUSE_BUTTON_LEFT)
	event.position = mouse_position
	event.pressed = pressed
	deliver(event)

func release_all() -> void:
	for index in active:
		touch_event(index,active[index],false)
	active.clear()
	for code in remote_keycodes:
		key_event(code,false)
	remote_keycodes.clear()
	for button in mouse_buttons:
		button_event(button,false)
	mouse_buttons.clear()

func _process(_delta: float) -> void:
	while socket.get_available_packet_count() > 0:
		var raw := socket.get_packet()
		if raw.size() > 4096:
			continue
		var data = JSON.parse_string(raw.get_string_from_utf8())
		if not data is Dictionary or data.get("token","") != secret:
			continue
		var incoming_instance := str(data.get("instance",""))
		if incoming_instance != instance:
			release_all()
			last_sequence = -1
			instance = incoming_instance
		var sequence := int(data.get("seq",-1))
		if sequence <= last_sequence:
			continue
		var points = data.get("touches",[])
		if not points is Array or points.size() > 10:
			continue
		var next: Dictionary = {}
		var valid := true
		var size := target_viewport.get_visible_rect().size if target_viewport else Vector2(get_window().size)
		for point in points:
			if not point is Dictionary:
				valid = false
				break
			var index := int(point.get("id",-1))
			var x := float(point.get("x",-1))
			var y := float(point.get("y",-1))
			if index < 0 or index > 9 or next.has(index) or not is_finite(x) or not is_finite(y) or x < 0 or x > 1 or y < 0 or y > 1:
				valid = false
				break
			next[index] = Vector2(x,y) * size
		if not valid:
			continue
		last_sequence = sequence
		last_packet = Time.get_ticks_msec()
		if not target_viewport and not get_window().has_focus():
			release_all()
			continue
		for index in active:
			if not next.has(index):
				touch_event(index,active[index],false)
		for index in next:
			if not active.has(index):
				touch_event(index,next[index],true)
			else:
				var event := InputEventScreenDrag.new()
				event.index = index
				event.position = next[index]
				event.relative = next[index]-active[index]
				deliver(event)
		active = next
		var keys: Dictionary = {}
		for key in data.get("keys",[]):
			var code := key_code(str(key))
			if code != 0:
				keys[code] = true
		for code in remote_keycodes:
			if not keys.has(code):
				key_event(code,false)
		for code in keys:
			if not remote_keycodes.has(code):
				key_event(code,true)
		remote_keycodes = keys
		var buttons: Dictionary = {}
		for button in data.get("buttons",[]):
			buttons[button] = true
		for button in mouse_buttons:
			if not buttons.has(button):
				button_event(button,false)
		for button in buttons:
			if not mouse_buttons.has(button):
				button_event(button,true)
		mouse_buttons = buttons
		var movement := Vector2(float(data.get("dx",0)),float(data.get("dy",0)))
		if movement != Vector2.ZERO:
			mouse_position = (mouse_position+movement).clamp(Vector2.ZERO,size)
			var event := InputEventMouseMotion.new()
			event.position = mouse_position
			event.relative = movement
			deliver(event)
	if (not active.is_empty() or not remote_keycodes.is_empty() or not mouse_buttons.is_empty()) and Time.get_ticks_msec()-last_packet > 800:
		release_all()

func _exit_tree() -> void:
	release_all()
	socket.close()
