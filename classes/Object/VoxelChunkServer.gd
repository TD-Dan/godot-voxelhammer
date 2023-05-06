extends Object

class_name VoxelChunkServer

## Manages a consistent state of loaded chunks
# - Keeps active chunk area in rectangular shape
# - signals state changes for all chunks


signal new_chunk_created
signal chunk_loaded
signal chunk_activated
signal chunk_deactivated
signal chunk_unloaded


var chunk_size
var chunks : Dictionary = {}

func _init(chunk_size = 16):
	self.chunk_size = chunk_size


func get_chunk_at(pos : Vector3i, create_missing = true):
	var index_position = pos.snapped(Vector3i(chunk_size,chunk_size,chunk_size))
	var found_chunk = chunks.get(index_position)
	if found_chunk:
		return found_chunk
