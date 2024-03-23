@tool

extends Node

class_name Chunkable

## Can be added as a child node to any Node3D to make that object possible to be contained inside a Chunk3D node
## 
## defines persistent data to be saved alongside the chunk
## provides signals for the parent to connnect to for receiving info on chunk events



var initialized = false
var loaded = false
var active = false




## Get a filename that contains size and position metadata
static func get_filename(size, position) -> String:
	return "%s_%s_%s_%s" % [size, position.x/size, position.y/size, position.z/size]
