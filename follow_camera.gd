extends RefCounted

const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 22.0
const MIN_POLAR := 0.35
const MAX_POLAR := 1.42
var host: Node
var yaw_target := 0.0
var polar_target := atan2(11.0,5.1)
var distance_target := sqrt(11.0*11.0+5.1*5.1)
var yaw := 0.0
var polar := atan2(11.0,5.1)
var distance := sqrt(11.0*11.0+5.1*5.1)
var target := Vector3.ZERO
var idle := 99.0
var house_bounds := Rect2()

func initialize(game: Node) -> void:
	host = game
	target = host.player.global_position + Vector3(0,1.7,0)
	if FileAccess.file_exists("res://data/world-map.json"):
		var house: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world-map.json")).house
		house_bounds = Rect2(Vector2(house.origin.x+house.extent.minX-1,house.origin.z+house.extent.minZ-1),Vector2(house.extent.maxX-house.extent.minX+2,house.extent.maxZ-house.extent.minZ+2))

func drag(delta: Vector2) -> void:
	yaw_target -= delta.x / 1280 * PI
	polar_target = clampf(polar_target-delta.y / 720*PI,MIN_POLAR,MAX_POLAR)
	idle = 0

func zoom(factor: float) -> void:
	distance_target = clampf(distance_target*factor,MIN_DISTANCE,MAX_DISTANCE)
	idle = 0

func reset() -> void:
	yaw_target = host.avatar.rotation.y+PI
	polar_target = 1.15
	distance_target = 9
	idle = 0

func update(delta: float) -> void:
	idle += delta
	var player_position: Vector3 = host.player.get_global_transform_interpolated().origin
	if idle > 1.5 and Vector2(host.player.velocity.x,host.player.velocity.z).length() > 0.5 and house_bounds.has_point(Vector2(player_position.x,player_position.z)):
		var behind: float = host.avatar.rotation.y+PI
		var difference := wrapf(behind-yaw_target,-PI,PI)
		if absf(difference)>0.02 and absf(difference)<1.05:
			yaw_target += difference*minf(1,delta*cos(difference))
	var weight := 1-exp(-delta/0.12)
	yaw = lerp_angle(yaw,yaw_target,weight)
	polar = lerpf(polar,polar_target,weight)
	distance = lerpf(distance,distance_target,weight)
	target = target.lerp(player_position+Vector3(0,1.7,0),1-pow(0.65,delta*60))
	var direction := Vector3(sin(yaw)*sin(polar),cos(polar),cos(yaw)*sin(polar))
	var query := PhysicsRayQueryParameters3D.create(target,target+direction*distance,1,[host.player.get_rid()])
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
	var actual := distance
	if not hit.is_empty():
		actual = minf(actual,maxf(host.camera.near*2,target.distance_to(hit.position)-0.4))
	host.camera.global_position = target+direction*actual
	var floor_height: float = host.traffic_ground_height(Vector2(host.camera.position.x,host.camera.position.z))+0.7
	host.camera.position.y = maxf(host.camera.position.y,floor_height)
	host.camera.look_at(target)
	host.camera_yaw = yaw
