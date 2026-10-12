extends Node

func _ready() -> void:
	if not await AssetPacks.ensure_pack("actors"):
		return
	var game: Node = load("res://main.tscn").instantiate()
	get_parent().add_child.call_deferred(game)
	queue_free()
