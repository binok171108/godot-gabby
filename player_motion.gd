extends RefCounted

const FLOAT_HEIGHT := 0.3

static func recover_floor_motion(body: CharacterBody3D, previous: Transform3D, motion: Vector3) -> bool:
	if motion.length_squared()<0.000001 or body.get_slide_collision_count()==0:
		return false
	var travelled := body.global_position-previous.origin
	travelled.y = 0
	if travelled.dot(motion.normalized())>=motion.length()*0.8:
		return false
	for index in range(body.get_slide_collision_count()):
		if body.get_slide_collision(index).get_normal().dot(Vector3.UP)<cos(body.floor_max_angle):
			return false
	var rise := maxf(body.safe_margin*3,0.003)
	var ceiling := KinematicCollision3D.new()
	if body.test_move(previous,Vector3.UP*rise,ceiling,body.safe_margin) and ceiling.get_normal().dot(Vector3.UP)<-0.1:
		return false
	var elevated := previous
	elevated.origin.y += rise
	if body.test_move(elevated,motion,null,body.safe_margin):
		return false
	body.global_position = elevated.origin+motion
	body.velocity.y = 0
	return true

static func step(body: CharacterBody3D, previous: Transform3D, motion: Vector3) -> bool:
	if motion.length_squared()<0.000001:
		return false
	var travelled := body.global_position-previous.origin
	travelled.y = 0
	if travelled.dot(motion.normalized())>=motion.length()*0.8:
		return false
	var ceiling := KinematicCollision3D.new()
	if body.test_move(previous,Vector3.UP*FLOAT_HEIGHT,ceiling,body.safe_margin) and ceiling.get_normal().dot(Vector3.UP)<-0.1:
		return false
	var elevated := previous
	elevated.origin.y += FLOAT_HEIGHT
	var probe_motion := motion.normalized()*maxf(motion.length(),0.35)
	if body.test_move(elevated,probe_motion,null,body.safe_margin):
		return false
	elevated.origin += probe_motion
	var landing := KinematicCollision3D.new()
	if not body.test_move(elevated,Vector3.DOWN*(FLOAT_HEIGHT+body.floor_snap_length),landing,body.safe_margin):
		return false
	if landing.get_normal().dot(Vector3.UP)<cos(body.floor_max_angle):
		return false
	var point := elevated.origin+landing.get_travel()
	if point.y<=previous.origin.y+0.001 or point.y>previous.origin.y+FLOAT_HEIGHT+0.001:
		return false
	body.global_position = previous.origin+motion+Vector3.UP*(point.y-previous.origin.y)
	body.velocity.y = 0
	body.apply_floor_snap()
	return true
