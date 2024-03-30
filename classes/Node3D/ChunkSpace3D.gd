@tool

extends Node3D

class_name ChunkSpace3D

## Manages a target amount of loaded chunks around given hotspots
##
## - Keeps a target amount of loaded chunks in memory
## - Keeps a target radious of active chunks around hotspots
## - Signals state changes for all chunks
## ! Does not know and does not need to know about chunk contents or their internal loading processes


## New Chunk3D was added to the graph
signal chunk_added(chunk)

## Chunk3D was removed to the graph
signal chunk_removed(chunk)

## Chunk size
@export var chunk_size : Vector3i = Vector3i(16,16,16):
	set(nv):
		chunk_size = nv
		_half_chunk = chunk_size / 2
# helper to get half chunk size without calculations
var _half_chunk : Vector3i


## Dictionary of key:value as Vector3i:Chunk
var chunks_by_position : Dictionary = {}


# Hotspots keep chunks loaded/active around them
var _hotspots : Array[Node3D] = []

## Add new hotspot keep chunks loaded/active around
func add_hotspot(hotspot : Node3D):
	_hotspots.append(hotspot)
	process_mode = Node.PROCESS_MODE_INHERIT

## Remove previously added hotspot keep chunks loaded/active around
func remove_hotspot(hotspot : Node3D):
	_hotspots.erase(hotspot)
	if _hotspots.is_empty():
		process_mode = Node.PROCESS_MODE_DISABLED


## Distance for chunks to update around hotspots
@export var active_area : Vector3i = Vector3i(4,4,4):
	set(nv):
		active_area = nv
		_total_chunks_in_area = active_area.x * active_area.y * active_area.z

var _total_chunks_in_area = 0


var hotspot_iterator : int = -1
var start_point : Vector3i
var ix = 0
var iy = 0
var iz = 0

func _ready():
	hotspot_iterator = -1
	if _hotspots.is_empty():
		process_mode = Node.PROCESS_MODE_DISABLED


func _process(_delta):
	if hotspot_iterator >= 0 and hotspot_iterator < _hotspots.size():
		
		get_chunk_at(start_point + Vector3i(ix, iy, iz)*chunk_size)
		
		ix += 1
		if ix < active_area.x: return
		else:
			ix = 0
			iy += 1
			if iy < active_area.y: return
			else:
				iy = 0
				iz += 1
				if iz < active_area.z: return
				else:
					iz = 0
	
	hotspot_iterator += 1
	if hotspot_iterator >= _hotspots.size():
		hotspot_iterator = 0
		for chunk in chunks_by_position.values():
			if not chunk.active:
				chunks_by_position.erase(chunks_by_position.find_key(chunk))
				chunk_removed.emit(chunk)
				chunk.queue_free()
			chunk.active = false
	
	start_point = Vector3i(_hotspots[hotspot_iterator].global_position) - ((chunk_size*active_area)/2)


## Translate global coordinate into chunk coordinate
func to_chunk(point: Vector3i) -> Vector3i:
	var snapped_position = point.snapped(chunk_size)/chunk_size
	return snapped_position


## Get the chunk that contains the given point
func get_chunk_at(point : Vector3i, generate_missing = true) -> Chunk3D:
	#print("%s: getting chunk at %s" % [self, point])
	var in_chunkspace = to_chunk(point)
	#print("%s: = chunk position %s" % [self, in_chunkspace])
	var found_chunk = chunks_by_position.get(in_chunkspace)
	if found_chunk:
		found_chunk.active = true
		return found_chunk
	elif generate_missing:
		var new_chunk = Chunk3D.new()
		new_chunk.chunk_position = to_chunk(point)
		new_chunk.chunk_size = chunk_size
		
		chunks_by_position[new_chunk.chunk_position] = new_chunk
		chunk_added.emit(new_chunk)
		new_chunk.active = true
		return new_chunk
	else:
		return null

