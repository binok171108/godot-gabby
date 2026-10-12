extends Node3D

const Sim = preload("res://train_sim.gd")
var host: Node
var sim: RefCounted
var cars: Array[Node3D] = []
var riding := false
var render_clock := 0.0
var templates: Array[PackedScene] = []
var visual_models: Dictionary = {}

func initialize(game: Node) -> void:
	host = game
	host.streaming.register_provider(self)
	sim = Sim.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/train.json")))
	var library: Node3D = load("res://assets/r3f-train.glb").instantiate()
	host.models.restore_vertex_colors(library)
	for index in range(sim.data.lengths.size()):
		var original: Node3D = library.find_child("TrainCar_"+str(index),true,false)
		assert(original != null, "Thiếu toa tàu gốc")
		templates.append(host.models.scene_template(original))
		var node := Node3D.new()
		add_child(node)
		cars.append(node)
	library.free()
	place()
	stream_update()

func place() -> void:
	for index in range(cars.size()):
		cars[index].transform = sim.car(index)

func station_near() -> Dictionary:
	var player := Vector2(host.player.position.x,host.player.position.z)
	for station in sim.data.stations:
		if player.distance_to(Vector2(station.x,station.z))<3.2:
			return station
	return {}

func board() -> void:
	riding = true
	host.cancel_map_goal()
	host.player.velocity = Vector3.ZERO
	host.models.animate(host.avatar,"sit")

func leave() -> void:
	var point: Vector2 = sim.exit_point(Vector2(host.player.position.x,host.player.position.z))
	riding = false
	host.player.position = Vector3(point.x,host.traffic_ground_height(point)+0.1,point.y)
	host.player.velocity = Vector3.ZERO
	host.player.reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.picking_profile or host.loading_room:
		return
	sim.step(delta)
	place()
	if riding:
		var seat: Dictionary = sim.seat()
		host.player.position = seat.position-Vector3(0,0.47,0)
		host.avatar.rotation.y = seat.heading

func stream_update() -> void:
	for index in range(cars.size()):
		var car: Node3D = cars[index]
		var point := Vector2(car.global_position.x,car.global_position.z)
		var bounds := Rect2(point,Vector2.ZERO)
		var wanted: bool = host.streaming.should_retain(bounds) if visual_models.has(index) else host.streaming.should_load(bounds)
		if wanted and not visual_models.has(index):
			var visual: Node3D = templates[index].instantiate()
			visual.transform = Transform3D.IDENTITY
			car.add_child(visual)
			visual.reset_physics_interpolation()
			visual_models[index] = visual
			host.streaming.register_visuals(visual)
		elif not wanted and visual_models.has(index):
			var visual: Node3D = visual_models[index]
			car.remove_child(visual)
			visual.queue_free()
			visual_models.erase(index)
		if visual_models.has(index):
			visual_models[index].visible = host.streaming.is_active(bounds)
			host.models.update_render_range(visual_models[index],host.player.global_position)
