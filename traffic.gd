extends Node3D

const Sim = preload("res://traffic_sim.gd")
var sim: RefCounted
var host: Node
var cars: Array[AnimatableBody3D] = []
var boats: Array[Node3D] = []
var elapsed := 0.0
var render_clock := 0.0
var templates: Dictionary = {}
var visual_models: Dictionary = {}
var car_model_names: Array = []
var boat_model_names: Array = []

func initialize(game: Node) -> void:
	host = game
	host.streaming.register_provider(self)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/traffic.json"))
	sim = Sim.new(data)
	car_model_names = data.carModels
	boat_model_names = data.boatModels
	var library: Node3D = load("res://assets/r3f-traffic.glb").instantiate()
	host.models.restore_vertex_colors(library)
	for index in range(sim.cars.size()):
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.9,1.4,4.2)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 0.75
		body.add_child(collision)
		var name: String = data.carModels[index]
		if not templates.has(name):
			var visual := model(library,name)
			templates[name] = host.models.scene_template(visual)
			visual.free()
		add_child(body)
		cars.append(body)
	for name in data.boatModels:
		var root := Node3D.new()
		if not templates.has(name):
			var visual := model(library,name)
			templates[name] = host.models.scene_template(visual)
			visual.free()
		add_child(root)
		boats.append(root)
	library.free()
	place()
	stream_update()

func model(library: Node3D, name: String) -> Node3D:
	var node_name := "Vehicle_" + name.replace("/","_").replace("-","_")
	var original: Node = library.find_child(node_name,true,false)
	assert(original != null, "Thiếu model phương tiện đúng nguồn: " + name)
	return original.duplicate()

func place() -> void:
	for index in range(cars.size()):
		var car: Dictionary = sim.cars[index]
		cars[index].position = Vector3(car.x,Sim.dream_height(Vector2(car.x,car.z)),car.z)
		cars[index].rotation.y = car.heading
	for index in range(boats.size()):
		var boat: Dictionary = sim.boats[index]
		boats[index].position = Vector3(boat.x,-0.34+sin(elapsed*1.6+boat.phase)*0.05,boat.z)
		boats[index].rotation = Vector3(0,boat.yaw,sin(elapsed*1.3+boat.phase)*0.04)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.picking_profile or host.loading_room:
		return
	elapsed += delta
	var player := {"x":host.player.position.x,"z":host.player.position.z,"roomId":null}
	var remaining := minf(delta,0.1)
	while remaining > 0.000001:
		sim.step_cars(minf(remaining,0.05),player)
		remaining -= 0.05
	sim.step_boats(minf(delta,0.1))
	place()

func stream_update() -> void:
	for family in range(2):
		var collection: Array = cars if family==0 else boats
		var names: Array = car_model_names if family==0 else boat_model_names
		for index in range(collection.size()):
			var vehicle: Node3D = collection[index]
			var key := str(family)+":"+str(index)
			var point := Vector2(vehicle.global_position.x,vehicle.global_position.z)
			var bounds := Rect2(point,Vector2.ZERO)
			var wanted: bool = host.streaming.should_retain(bounds) if visual_models.has(key) else host.streaming.should_load(bounds)
			if wanted and not visual_models.has(key):
				var visual: Node3D = templates[names[index]].instantiate()
				vehicle.add_child(visual)
				visual.reset_physics_interpolation()
				visual_models[key] = visual
				host.streaming.register_visuals(visual)
			elif not wanted and visual_models.has(key):
				var visual: Node3D = visual_models[key]
				vehicle.remove_child(visual)
				visual.queue_free()
				visual_models.erase(key)
			if vehicle is CollisionObject3D:
				vehicle.collision_layer = 1 if host.streaming.is_detailed(bounds) else 0
			if visual_models.has(key):
				visual_models[key].visible = host.streaming.is_active(bounds)
				host.models.update_render_range(visual_models[key],host.player.global_position)
