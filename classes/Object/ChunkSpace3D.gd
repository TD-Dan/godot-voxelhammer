@tool

extends Node3D

class_name ChunkSpace3D

## Manages a target amount of loaded chunks around given hotspots
##
## - Keeps a target amount of loaded chunks in memory
## - Keeps a target radious of active chunks around hotspots
## - Signals state changes for all chunks
## ! Does not know and does not need to know about chunk contents or its internal loading processes


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


## Hotspots keep chunks loaded/active around them
@export var hotspots : Array[Node3D] = Array[Node3D]


#func _ready():
#	pass


#func _exit_tree():
	#pass


#func _process(delta):
#	pass


## Translate global coordinate into chunk coordinate
func to_chunk(point: Vector3i) -> Vector3i:
	point -= _half_chunk
	var snapped_position = point.snapped(chunk_size)
	return snapped_position


## Get the chunk that contains the given point
func get_chunk_at(point : Vector3i) -> Chunk3D:
	#print("ChunkManager: getting chunk at %s" % point)
	
	var found_chunk = chunks_by_position.get(to_chunk(point))
	if found_chunk:
		return found_chunk
	
	var new_chunk = Chunk3D.new()
	new_chunk.name = Chunk.get_filename(chunk_size,snapped_position)
	new_chunk.position = snapped_position
	new_chunk.size = chunk_size
	
	chunks_by_position[new_chunk.position] = new_chunk
	new_chunk.initialized = true
	emit_signal("chunk_initialized", new_chunk)
	return new_chunk


## Load chunk data from disk or generate new chunk data
func load_chunk(chunk : Chunk):
	if chunk.loaded:
		push_error("%s: Trying to load already loaded chunk %s" % [self, chunk])
		return
	
	if FileAccess.file_exists(get_globalpath(chunk.position)):
		var disk_chunk = Chunk.load_from_disk(get_globalpath(chunk.position))
		chunks_by_position[chunk.position].persistent_data = disk_chunk.persistent_data
	else:
		emit_signal("new_chunk_created", chunk)
		
	loaded_chunks[chunk.position] = chunk
	chunk.loaded = true
	
	emit_signal("chunk_loaded", chunk)


## Designate chunk as active so as to update and potentially being displayed by a player
func activate_chunk(chunk : Chunk):
	if chunk.active:
		push_error("%s: Trying to activate already active chunk %s" % [self, chunk])
		return
	
	if not chunk.loaded:
		load_chunk(chunk)
	
	active_chunks[chunk.position] = chunk
	chunk.active = true
	emit_signal("chunk_activated", chunk)


func deactivate_chunk(chunk : Chunk):
	if not chunk.active:
		push_error("%s: Trying to deactivate already deactive chunk %s" % [self, chunk])
		return
	
	active_chunks.erase(chunk.position)
	chunk.active = false
	emit_signal("chunk_deactivated", chunk)


func unload_chunk(chunk : Chunk):
	if not chunk.loaded:
		push_error("%s: Trying to unload already unloaded chunk %s" % [self, chunk])
		return
	
	#print("ChunkManager: unloading chunk %s" % chunk)
	if chunk.active:
		deactivate_chunk(chunk)
	
	loaded_chunks.erase(chunk.position)
	chunk.loaded = false
	emit_signal("chunk_unloaded", chunk)
	chunk.persistent_data.clear()


func delete_chunk(chunk : Chunk):
	#if chunk.active:
	#	deactivate_chunk(chunk)
		#push_error("%s: Trying to remove active chunk %s\n Please deactivate first." % [self, chunk])
	if chunk.loaded:
		unload_chunk(chunk)
		#push_error("%s: Trying to remove loaded chunk %s\n Please unload first." % [self, chunk])
	
	emit_signal("chunk_deleted", chunk)
	chunk.transient_data.clear()
	chunks_by_position.erase(chunk.position)
	chunk.queue_free()


func _on_hotspot_deleted(hotspot):
	#print("ChunkManager: Received 'hotspot deleted' for %s" % hotspot)
	_update_all_hotspots()


## Gets the minimum axis length to closest hotspot and stores it to the chunk dist_to_closest_hotspot variable
func _calculate_distance_to_closest_hotspot_for(chunk):
	var first_iteration = true
	for hotspot in hotspots.keys():
		var dist_to_hotspot = Vector3( Vector3(chunk.position) - hotspot.global_position + Vector3(_half_chunk) ).abs()
		var cubic_dist = max(dist_to_hotspot.x, dist_to_hotspot.y, dist_to_hotspot.z)
		if first_iteration or chunk.dist_to_closest_hotspot > cubic_dist:
			chunk.dist_to_closest_hotspot = cubic_dist
		first_iteration = false
	emit_signal("shortest_distance_updated",chunk)


func get_globalpath(pos : Vector3i) -> String:
	return "%s/%s-%s/%s.%s" % [database_root_folder, database_name, database_uid, Chunk.get_filename(chunk_size, pos), database_format]
