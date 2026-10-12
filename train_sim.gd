extends RefCounted

var data: Dictionary
var distance := 0.0

func _init(source: Dictionary) -> void:
	data = source

func step(delta: float) -> void:
	distance = fposmod(distance+data.speed*delta,data.length)

func at(metres: float) -> Vector3:
	var index: float = fposmod(metres,data.length)/data.length*data.samples.size()
	var first: Array = data.samples[floori(index)]
	var second: Array = data.samples[(floori(index)+1)%data.samples.size()]
	return Vector3(lerpf(first[0],second[0],index-floor(index)),lerpf(first[1],second[1],index-floor(index)),lerp_angle(first[2],second[2],index-floor(index)))

func car(index: int) -> Transform3D:
	var back := 0.0
	for previous in range(index):
		back += data.lengths[previous]+0.6
	var point := at(distance-back-data.lengths[index]/2)
	return Transform3D(Basis(Vector3.UP,point.z+PI/2),Vector3(point.x,data.deck+data.railTop,point.y))

func seat() -> Dictionary:
	var transform := car(data.lengths.size()-1)
	return {"position":transform*Vector3(0,1.2,0),"heading":transform.basis.get_euler().y-PI/2}

func exit_point(position: Vector2) -> Vector2:
	var best := Vector3.ZERO
	var closest := INF
	for index in range(400):
		var point := at(float(index)/400*data.length)
		var distance_squared := position.distance_squared_to(Vector2(point.x,point.y))
		if distance_squared<closest:
			closest = distance_squared
			best = point
	var first := Vector2(best.x-cos(best.z)*3.9,best.y+sin(best.z)*3.9)
	var second := Vector2(best.x+cos(best.z)*3.9,best.y-sin(best.z)*3.9)
	for option in [first,second]:
		if not data.pillars.any(func(pillar): return option.distance_to(Vector2(pillar[0],pillar[1]))<2.2):
			return option
	return first
