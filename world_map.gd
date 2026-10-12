extends Control

signal map_requested
signal destination_selected(point: Vector2)
var host: Node
var data: Dictionary
var texture: Texture2D
var detailed := false
var refresh_clock := 0.0

func initialize(game: Node, large: bool = false) -> void:
	host = game
	detailed = large
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world-map.json"))
	texture = load("res://assets/world-map/" + ("large" if large else "atlas") + ".webp")
	mouse_filter = Control.MOUSE_FILTER_STOP
	if large:
		custom_minimum_size = Vector2(320,320 / data.aspect)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		position = Vector2(1085,85)
		size = Vector2(165,165)
		tooltip_text = "Bản đồ — chạm để mở"
	queue_redraw()

func map_to_world(point: Vector2) -> Vector2:
	var bounds: Dictionary = data.bounds
	return Vector2(lerpf(bounds.minX,bounds.maxX,point.x / size.x),lerpf(bounds.minZ,bounds.maxZ,point.y / size.y))

func world_to_map(point: Vector2) -> Vector2:
	var bounds: Dictionary = data.bounds
	if detailed:
		return Vector2((point.x-bounds.minX)/(bounds.maxX-bounds.minX)*size.x,(point.y-bounds.minZ)/(bounds.maxZ-bounds.minZ)*size.y)
	return size / 2 + (point-Vector2(host.player.position.x,host.player.position.z)) * size.x / 90

func marker(center: Vector2, facing: float, radius: float) -> void:
	var points := PackedVector2Array()
	for point in [Vector2(0,-1.5),Vector2(0.85,0.6),Vector2(0,0.2),Vector2(-0.85,0.6)]:
		points.append(center+(point*radius).rotated(PI-facing))
	draw_circle(center,radius*1.05,Color.WHITE)
	draw_colored_polygon(points,Color("f36d9c"))

func _draw() -> void:
	if not is_instance_valid(host) or not texture:
		return
	var center := size / 2
	var bounds: Dictionary = data.bounds
	var player := Vector2(host.player.position.x,host.player.position.z)
	if detailed:
		draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false)
	else:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var source_center := Vector2((player.x-bounds.minX)/(bounds.maxX-bounds.minX),(player.y-bounds.minZ)/(bounds.maxZ-bounds.minZ))
		for index in range(96):
			var direction := Vector2.from_angle(TAU*index/96)
			points.append(center+direction*(center.x-2))
			uvs.append(source_center+direction*Vector2(45/(bounds.maxX-bounds.minX),45/(bounds.maxZ-bounds.minZ)))
		draw_colored_polygon(points,Color.WHITE,uvs,texture)
		var cone := PackedVector2Array([center])
		var angle: float = atan2(-cos(host.camera_yaw),-sin(host.camera_yaw))
		for index in range(17):
			cone.append(center+Vector2.from_angle(angle-0.55+1.1*index/16)*center.x*0.9)
		draw_colored_polygon(cone,Color(1,1,1,0.22))
		for friend in data.friends:
			var point := world_to_map(Vector2(friend.x,friend.z))
			if point.distance_to(center) < center.x-5:
				draw_circle(point,5,Color.WHITE)
				draw_circle(point,3.5,Color(friend.color))
	if not host.map_goal.is_empty():
		var target := world_to_map(Vector2(host.map_goal.x,host.map_goal.z))
		var start := world_to_map(player)
		var length := start.distance_to(target)
		for offset in range(0,ceili(length),10):
			var first := start.lerp(target,minf(1,offset/maxf(1,length)))
			var last := start.lerp(target,minf(1,(offset+6)/maxf(1,length)))
			if detailed or (first.distance_to(center)<center.x-5 and last.distance_to(center)<center.x-5):
				draw_line(first,last,Color("f36d9c"),3,true)
		if detailed or target.distance_to(center)<center.x-5:
			draw_circle(target,5,Color("ff4f7e"))
	marker(world_to_map(player),host.avatar.rotation.y,8 if not detailed else 10)
	if not detailed:
		draw_arc(center,center.x-2,0,TAU,96,Color.WHITE,3,true)
		draw_string(ThemeDB.fallback_font,Vector2(center.x-5,16),"B",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e0496f"))

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if detailed:
			destination_selected.emit(map_to_world(event.position))
		else:
			map_requested.emit()
		accept_event()

func _process(delta: float) -> void:
	if not is_instance_valid(host):
		return
	visible = not host.picking_profile and host.state.room_id == "world"
	refresh_clock += delta
	if visible and refresh_clock >= 0.05:
		refresh_clock = 0
		queue_redraw()
