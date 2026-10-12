extends SceneTree
const Codec = preload("res://asset_codec.gd")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var directory: String = arguments[0]
	var manifest_path := directory+"/delivery-manifest.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var raw_total := 0
	var wire_total := 0
	for id in manifest:
		var entry: Dictionary = manifest[id]
		var filename: String = entry.file.get_file()
		var raw := FileAccess.get_file_as_bytes(directory+"/"+filename)
		var encoded := raw.compress(FileAccess.COMPRESSION_ZSTD)
		if encoded.size()<raw.size():
			var wire_hash := Codec.sha256(encoded)
			var wire_name := filename+"-"+wire_hash.left(16)+".zst"
			var file := FileAccess.open(directory+"/"+wire_name,FileAccess.WRITE)
			file.store_buffer(encoded)
			file.close()
			entry.cache_file = filename
			entry.file = "packs/"+wire_name
			entry.codec = "zstd"
			entry.wire_bytes = encoded.size()
			entry.wire_sha256 = wire_hash
		raw_total += raw.size()
		wire_total += entry.get("wire_bytes",raw.size())
	var output := FileAccess.open(manifest_path,FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest))
	output.close()
	print("PACK_DELIVERY ",raw_total," raw bytes -> ",wire_total," wire bytes, lossless Zstd")
	quit()
