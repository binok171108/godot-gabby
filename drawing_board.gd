extends Control

var strokes: Array = []
var active: Dictionary = {}
var ink := Color("e46d99")
var paper: PackedVector2Array = PackedVector2Array()
var dragging := false
var fold_callback: Callable

func _ready() -> void:
	custom_minimum_size = Vector2(700, 280)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	draw_style_box(make_background(), Rect2(Vector2.ZERO, size))
	if not paper.is_empty():
		var polygon := PackedVector2Array()
		for point in paper:
			polygon.append(Vector2(size.x / 2 + point.x * 260, size.y / 2 - point.y * 260))
		draw_colored_polygon(polygon, Color("e6b0d5"))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("9b598c"), 3, true)
	for stroke in strokes:
		if stroke.points.size() > 1:
			draw_polyline(stroke.points, stroke.color, 5, true)
	if not active.is_empty() and active.points.size() > 1:
		draw_polyline(active.points, active.color, 5, true)

func make_background() -> StyleBoxFlat:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("fffaf1")
	return background

func pointer(point: Vector2, pressed: bool, movement: bool = false) -> void:
	if not movement:
		if pressed:
			dragging = true
			active = {"color":ink,"points":PackedVector2Array([point])}
		else:
			if dragging:
				strokes.append(active)
				if fold_callback.is_valid():
					fold_callback.call(active.points[0], point)
			dragging = false
			active = {}
	elif dragging:
		active.points.append(point)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer(event.position, event.pressed)
	elif event is InputEventMouseMotion:
		pointer(event.position, true, true)
	elif event is InputEventScreenTouch:
		pointer(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		pointer(event.position, true, true)
