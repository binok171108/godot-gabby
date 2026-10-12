extends Control

signal jump_requested
signal interact_requested

var axis := Vector2.ZERO
var running := false
var joystick_finger := -1
var run_finger := -1
var origin := Vector2(145, 600)
var knob := Vector2.ZERO
var mouse_down := false
var enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not enabled:
		return
	draw_circle(origin, 86, Color(0.08, 0.14, 0.23, 0.65))
	draw_arc(origin, 86, 0, TAU, 64, Color("b9e5ef"), 3, true)
	draw_circle(origin + knob, 35, Color("f2ce79"))
	for definition in [[Vector2(1140, 600), "NHẢY", Color("eaa1bd")], [Vector2(1010, 630), "CHẠY", Color("9cd9cf")], [Vector2(1150, 460), "CHƠI", Color("d0b7ef")]]:
		draw_circle(definition[0], 55, definition[2])
		draw_string(ThemeDB.fallback_font, definition[0] + Vector2(-36, 6), definition[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("25394c"))

func update_axis(point: Vector2) -> void:
	axis = ((point - origin) / 65.0).limit_length(1.0)
	knob = axis * 65
	queue_redraw()

func release() -> void:
	axis = Vector2.ZERO
	knob = Vector2.ZERO
	running = false
	joystick_finger = -1
	run_finger = -1
	mouse_down = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.index == joystick_finger:
				joystick_finger = -1
				update_axis(origin)
			if event.index == run_finger:
				running = false
				run_finger = -1
			return
		if event.position.distance_to(origin) < 105 and joystick_finger == -1:
			joystick_finger = event.index
			update_axis(event.position)
		elif event.position.distance_to(Vector2(1140, 600)) < 58:
			jump_requested.emit()
		elif event.position.distance_to(Vector2(1010, 630)) < 58:
			running = true
			run_finger = event.index
		elif event.position.distance_to(Vector2(1150, 460)) < 58:
			interact_requested.emit()
	elif event is InputEventScreenDrag and event.index == joystick_finger:
		update_axis(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(origin) < 105:
			mouse_down = true
			update_axis(event.position)
		elif not event.pressed and mouse_down:
			mouse_down = false
			update_axis(origin)
		elif event.pressed and event.position.distance_to(Vector2(1140, 600)) < 58:
			jump_requested.emit()
		elif event.pressed and event.position.distance_to(Vector2(1150, 460)) < 58:
			interact_requested.emit()
	elif event is InputEventMouseMotion and mouse_down:
		update_axis(event.position)
