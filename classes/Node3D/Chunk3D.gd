extends Node3D

class_name Chunk3D

## Represents a cube area of potentially infinite 3d space
##
## stores position/size of the area


## chunkspace position of the chunk
@export var chunk_position : Vector3i
## Real world size of the chunk
@export var chunk_size : Vector3i = Vector3i(16,16,16)


func _enter_tree():
	name = generate_name()


func generate_name() -> String:
	return "Chunk3D_%s_%s_%s_%s_%s_%s" % [chunk_size.x,chunk_size.y, chunk_size.z, chunk_position.x, chunk_position.y, chunk_position.z]
