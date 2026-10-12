extends RefCounted

var cars: Array
var boats: Array

func _init(data: Dictionary) -> void:
	cars = data.cars.duplicate(true)
	boats = data.boats.duplicate(true)

static func at_line(line: Dictionary, distance: float) -> Dictionary:
	var points: Array = line.points
	var accum := PackedFloat64Array([0.0])
	for index in range(1, points.size()):
		accum.append(accum[-1] + Vector2(points[index][0], points[index][1]).distance_to(Vector2(points[index-1][0], points[index-1][1])))
	var sample := clampf(distance, 0, accum[-1])
	var lower := 0
	var upper := accum.size() - 1
	while upper - lower > 1:
		var middle := (lower + upper) >> 1
		if accum[middle] <= sample:
			lower = middle
		else:
			upper = middle
	var start := Vector2(points[lower][0], points[lower][1])
	var end := Vector2(points[upper][0], points[upper][1])
	var length := accum[upper] - accum[lower]
	if length == 0:
		length = 1
	var point := start.lerp(end, (sample - accum[lower]) / length)
	var tangent := (end - start) / length
	return {"x":point.x,"z":point.y,"tx":tangent.x,"tz":tangent.y}

static func place_car(car: Dictionary) -> float:
	var point := at_line(car.route, car.s)
	var tangent: Vector2 = Vector2(point.tx, point.tz) * car.dir
	car.x = point.x + tangent.y * 1.4
	car.z = point.z - tangent.x * 1.4
	return atan2(tangent.x, tangent.y)

static func blocked(car: Dictionary, point: Vector2, distance: float) -> bool:
	var difference := point - Vector2(car.x, car.z)
	var forward := Vector2(sin(car.heading), cos(car.heading))
	var along := difference.dot(forward)
	var side := absf(-difference.x * forward.y + difference.y * forward.x)
	return along > 0 and along < distance and side < 2.2

func step_cars(delta: float, player: Dictionary) -> void:
	for car in cars:
		var kid: bool = not player.get("roomId") and blocked(car, Vector2(player.x, player.z), 7)
		var by_car := false
		car.ghost = maxf(0, car.ghost - delta)
		if not kid and car.ghost <= 0:
			for other in cars:
				if other.id != car.id and blocked(car, Vector2(other.x, other.z), 7.5):
					by_car = true
					break
		car.wait = car.wait + delta if by_car else 0
		if car.wait > 3:
			car.ghost = 3
			car.wait = 0
			by_car = false
		var want: float = 0 if kid or by_car else car.speed
		car.v += clampf(want - car.v, -9 * delta, 4 * delta)
		car.s += car.v * delta * car.dir
		if car.s >= car.route.len - 2 or car.s <= 2:
			car.dir = 1 if car.s <= 2 else -1
			car.s = clampf(car.s, 2.01, car.route.len - 2.01)
			car.turning = 1
		var heading := place_car(car)
		car.heading += atan2(sin(heading-car.heading), cos(heading-car.heading)) * minf(1, delta * (3 if car.turning > 0 else 8))
		car.turning = maxf(0, car.turning - delta)

func step_boats(delta: float) -> void:
	for boat in boats:
		if boat.turn > 0:
			boat.turn -= delta
			boat.yaw += PI / 2.5 * delta * boat.dir
			if boat.turn <= 0:
				boat.dir = -boat.dir
			continue
		boat.s += boat.dir * boat.speed * delta
		if boat.s > boat.span.b or boat.s < boat.span.a:
			boat.s = clampf(boat.s, boat.span.a, boat.span.b)
			boat.turn = 2.5
		var point := at_line(boat.span.line, boat.s)
		boat.x = point.x + point.tz * boat.side
		boat.z = point.z - point.tx * boat.side
		boat.yaw = atan2(point.tx * boat.dir, point.tz * boat.dir)

static func dream_height(point: Vector2) -> float:
	var hill := maxf(0, 1 - pow(point.x / 65, 2) - pow((point.y + 183) / 32, 2))
	return 24 * pow(hill, 1.7) + 0.7 * pow(maxf(0, 1 - pow((point.x - 80) / 14, 2) - pow((point.y + 172) / 12, 2)), 2)
