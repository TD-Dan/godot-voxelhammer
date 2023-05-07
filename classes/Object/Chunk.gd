@tool

extends Node

class_name Chunk

@export var position : Vector3i = Vector3i.ZERO
@export var size : int = 16

@export var persistent_data : Dictionary = Dictionary()
var transient_data : Dictionary = Dictionary()

var active = false

func save_to_disk(completefilepath):
		var packet = PackedScene.new()
		var save_node = self
		var error = packet.pack(save_node)
		if error:
			push_error("Chunk packing for saving failed: %s" % error_string(error))
		error = ResourceSaver.save(packet, completefilepath, ResourceSaver.FLAG_COMPRESS)
		if error:
			push_error("Chunk save to %s failed: %s" % [completefilepath, error_string(error)])

static func load_from_disk(completefilepath):
	print("Chunk loading from disk : " + completefilepath)
	var load_packet : PackedScene = ResourceLoader.load(completefilepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	return load_packet.instantiate()

static func get_filename(size, position) -> String:
	return "%s_%s_%s_%s" % [size, position.x/size, position.y/size, position.z/size]
