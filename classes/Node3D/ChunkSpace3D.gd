@tool

extends Node3D

class_name ChunkSpace3D

## Manages a target amount of loaded chunks around given hotspots
##
## - Keeps a target amount of loaded chunks in memory
## - Keeps a target radious of active chunks around hotspots
## - Signals state changes for all chunks
## ! Does not know and does not need to know about chunk contents or their internal loading processes


## Chunk size
@export var chunk_size : Vector3i = Vector3i(16,16,16):
	set(nv):
		chunk_size = nv
		_half_chunk = Vector3i(nv.x/2,nv.y/2,nv.z/2)
# helper to get half chunk size without calculations
var _half_chunk : Vector3i


## Wether to utilize threading for chunk logic
@export var use_threads : bool


## Dictionary of key:value as Vector3i:Chunk
var chunks_by_position : Dictionary = {}


# Hotspots keep chunks loaded/active around them
var _hotspots : Array[Node3D] = []

## Add new hotspot keep chunks loaded/active around
func add_hotspot(hotspot : Node3D):
	_hotspots.append(hotspot)

## Remove previously added hotspot keep chunks loaded/active around
func remove_hotspot(hotspot : Node3D):
	_hotspots.erase(hotspot)


## Distance for chunks to update around hotspots
@export var active_radius : int = 4


## Translate global coordinate into chunk coordinate
func to_chunk(point: Vector3i) -> Vector3i:
	point -= _half_chunk
	var snapped_position = point.snapped(chunk_size)
	return snapped_position


## Get the chunk that contains the given point
func get_chunk_at(point : Vector3i, generate_missing = true) -> Chunk3D:
	#print("ChunkManager: getting chunk at %s" % point)
	
	var found_chunk = chunks_by_position.get(to_chunk(point))
	if found_chunk:
		return found_chunk
	elif generate_missing:
		var new_chunk = Chunk3D.new()
		new_chunk.chunk_position = to_chunk(point)
		new_chunk.chunk_size = chunk_size
		
		chunks_by_position[new_chunk.chunk_position] = new_chunk
		return new_chunk
	else:
		return null

