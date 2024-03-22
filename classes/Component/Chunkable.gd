@tool

extends Node

class_name Chunkable

## Can be added as a child node to any Node3D to make that object possible to be contained inside a Chunk3D node
## 
## defines persistent data to be saved alongside the chunk
## provides signals for the parent to connnect to for receiving info on chunk events


## Data that is saved between sessions
@export var persistent_data : Dictionary = Dictionary()

var initialized = false
var loaded = false
var active = false

## Chunk contents has been changed
var data_changed = false

## shortest axial distance to nearest hotspot in cubic space
var dist_to_closest_hotspot : float = 0.0:
	set(nv):
		dist_to_closest_hotspot = nv
		_sorted_array_key = nv

## needed for inserting into a SortedArray, set in dist_to_closest_hotspot setter
var _sorted_array_key : int

## Save all persistent_data to disk
func save_to_disk(completefilepath):
	#print("Chunk saving to disk : " + completefilepath)
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
	#print("Chunk loading from disk : " + completefilepath)
	var load_packet : PackedScene = ResourceLoader.load(completefilepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	return load_packet.instantiate()


## Get a filename that contains size and position metadata
static func get_filename(size, position) -> String:
	return "%s_%s_%s_%s" % [size, position.x/size, position.y/size, position.z/size]
