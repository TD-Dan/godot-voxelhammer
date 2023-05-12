@tool

extends Node

class_name Chunk

## Real world snapped position of the chunk
@export var position : Vector3i = Vector3i.ZERO

@export var size : int = 16

## Data that is saved between sessions
@export var persistent_data : Dictionary = Dictionary()
## Data that is not saved to disk and gets discarded after Chunk has been unloaded
var transient_data : Dictionary = Dictionary()

var active = false

## Chunk contents has been changed
var data_changed = false

var dist_to_closest_hotspot = 0

## Save all persistent_data to disk
func save_to_disk(completefilepath):
	print("Chunk saving to disk : " + completefilepath)
	var packet = PackedScene.new()
	var save_node = self
	var error = packet.pack(save_node)
	if error:
		push_error("Chunk packing for saving failed: %s" % error_string(error))
		return
	error = ResourceSaver.save(packet, completefilepath, ResourceSaver.FLAG_COMPRESS)
	if error:
		push_error("Chunk save to %s failed: %s" % [completefilepath, error_string(error)])
		return
	data_changed = false

## Load all persistent_data from disk and return a Chunk containing it
static func load_from_disk(completefilepath):
	print("Chunk loading from disk : " + completefilepath)
	var load_packet : PackedScene = ResourceLoader.load(completefilepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	return load_packet.instantiate()


## Get a filename that contains size and position metadata
static func get_filename(size, position) -> String:
	return "%s_%s_%s_%s" % [size, position.x/size, position.y/size, position.z/size]
