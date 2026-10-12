extends Node

var host: Node
var entries: Array[Dictionary] = []
var loaded: Dictionary = {}
var busy := false
var refresh_clock := 0.0
var requests := 0
var unloads := 0
var max_model_load_usec := 0

func initialize(game: Node) -> void:
	host = game
	host.streaming.register_provider(self)
	for friend in host.content.world.friends:
		entries.append({"id":"friend_"+friend.id,"asset":friend.get("model","dream-figure-"+friend.id),"point":Vector3(friend.x,host.traffic_ground_height(Vector2(friend.x,friend.z)),friend.z),"friend":friend})
	for index in range(host.content.world.get("spectators",[]).size()):
		var spectator: Dictionary = host.content.world.spectators[index]
		entries.append({"id":"spectator_"+str(index),"asset":spectator.model,"point":Vector3(spectator.x,spectator.y,spectator.z),"spectator":true})
	await refresh(true)

static func pack_id(asset: String) -> String:
	return "actor_"+asset.replace("/","_").replace("-","_")

func refresh(initial: bool = false) -> void:
	if busy:
		return
	busy = true
	var focus := Vector2(host.player.position.x,host.player.position.z)
	for entry in entries:
		var point := Vector2(entry.point.x,entry.point.z)
		var bounds := Rect2(point,Vector2.ZERO)
		if loaded.has(entry.id):
			if not host.streaming.should_retain(bounds):
				var node: Node3D = loaded[entry.id]
				node.get_parent().remove_child(node)
				node.queue_free()
				loaded.erase(entry.id)
				unloads += 1
				var path: String = node.get_meta("asset_path","")
				if not loaded.values().any(func(other): return other.get_meta("asset_path","") == path):
					host.models.cache.erase(path)
				continue
			var model: Node3D = loaded[entry.id]
			model.visible = host.streaming.is_active(bounds)
			host.models.update_render_range(model,host.player.global_position)
			var animation: AnimationPlayer = host.models.animation_player(model)
			if animation:
				animation.process_mode = Node.PROCESS_MODE_INHERIT if host.streaming.is_detailed(bounds) else Node.PROCESS_MODE_DISABLED
			if entry.has("friend") and host.streaming.is_detailed(bounds):
				model.rotation.y = atan2(focus.x-point.x,focus.y-point.y)
			continue
		if not host.streaming.should_load(bounds):
			continue
		if not await host.streaming.request_pack(pack_id(entry.asset),point,initial):
			continue
		var path: String = "res://assets/"+("ai/" if host.models.required_ai.has(entry.asset) else "")+entry.asset+".glb"
		if not ResourceLoader.exists(path):
			push_error("Thiếu model nhân vật đúng nguồn: "+path)
			continue
		var started := Time.get_ticks_usec()
		var model: Node3D = host.models.instantiate(entry.asset)
		var elapsed := Time.get_ticks_usec()-started
		max_model_load_usec = maxi(max_model_load_usec,elapsed)
		if OS.has_feature("web") and elapsed>50000:
			print("SLOW_ACTOR ",entry.asset," ",elapsed," us")
		model.name = "Friend_"+entry.friend.id if entry.has("friend") else entry.id
		host.scenery.add_child(model)
		host.fit_actor(model,entry.asset,1.69 if entry.has("friend") else 1.55)
		model.position += entry.point
		model.reset_physics_interpolation()
		model.visible = host.streaming.is_active(bounds)
		host.models.update_render_range(model,host.player.global_position)
		host.models.animate(model,"idle" if entry.has("friend") else "wave")
		var animation: AnimationPlayer = host.models.animation_player(model)
		if animation and not host.streaming.is_detailed(bounds):
			animation.process_mode = Node.PROCESS_MODE_DISABLED
		if entry.has("friend"):
			host.label3d(model,entry.friend.name,Vector3(0,2.5,0))
		else:
			model.rotation.y = PI
		loaded[entry.id] = model
		host.streaming.register_visuals(model)
		requests += 1
		if OS.has_feature("web"):
			await get_tree().process_frame
	busy = false

func info() -> Dictionary:
	var animated := 0
	for model in loaded.values():
		var animation: AnimationPlayer = host.models.animation_player(model)
		if animation and animation.process_mode != Node.PROCESS_MODE_DISABLED:
			animated += 1
	return {"loaded":loaded.size(),"animated":animated,"requests":requests,"unloads":unloads,"busy":busy,"maxModelLoadUsec":max_model_load_usec}

func _process(delta: float) -> void:
	if get_meta("streaming_managed",false) or not is_instance_valid(host) or host.picking_profile or host.loading_room:
		return
	refresh_clock += delta
	if refresh_clock>=0.25:
		refresh_clock = 0
		refresh()

func stream_update() -> void:
	refresh()
