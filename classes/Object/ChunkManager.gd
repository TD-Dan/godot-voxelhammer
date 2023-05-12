@tool

extends Node

class_name ChunkManager

## Manages a persistent state of loaded chunks
##
## - Keeps a target amount of loaded chunks in memory
## - Keeps a target amount of active chunks around hotspots
## - Signals state changes for all chunks
## ! Does not know and does not need to know about chunk contents

## Completely new chunk is being generated
signal new_chunk_created

## Existing chunk has been loaded into memory, but not yet active
signal chunk_loaded

## Chunk is added to the active world area
signal chunk_activated

## Chunk is removed from the active world area, but not unloaded
signal chunk_deactivated

## Chunk is completely removed from memory and potentially written to disk
signal chunk_unloaded

@export var chunk_size : int = 16:
	set(nv):
		chunk_size = nv
		half_chunk = Vector3i(nv/2,nv/2,nv/2)
@export var half_chunk : Vector3i

@export_group("Database File")
## database base folder, usually "user://somefolder"
@export var database_folder : String = ""
## unique id to distinguish for different saves/users, even if they use same database name
@export var database_uid : String = ""
## Human readable part of database name
@export var database_name : String = ""
## Savefile format, currently supported tscn and scn
@export var database_format : String = ""

## Create database folder if it does not exist
## Note to not try: this could be made to happen automatically when any database_* variables changes, but in editor this will create all folders from editing the prompts like : "d", "da", "dat", "data" ... as godot refreshes variable after every edit
@export var create_database_folder : bool = false:
	set(nv): rebuild_database_folder()

@export_group("Chunk generation")
## How many chunks to keep in memory, even if some of them are not active. This can mitigate unneeded disk trashing
@export var max_chunks : int = 50
## Maximum active chunks. This can be interpreted as chunks that are drawn and receive _process signals f.ex. Proper activvation logic needs to be implemented by listening to chunk_activated / chunk_deactivated signals
@export var max_active : int = 20

## Wether to utilize threading for chunk logic and file read/write
@export var thread_mode : VoxelConfiguration.THREAD_MODE = VoxelConfiguration.THREAD_MODE.NONE:
	set(nv):
		if nv != VoxelConfiguration.THREAD_MODE.NONE:
			push_warning("Only THREAD_MODE.NONE is implemented.")

## Dictionary of key:value as Vector3i:Chunk
var chunks : Dictionary = {}
## Dictionary of Vector3i:Chunk mappings of active chunks
var active_chunks : Dictionary = {}


class HotspotData:
	var radius : int = 0


## Hotspots keep chunks active around them
## Format in key:value as Node3D:HotSpotData
var hotspots : Dictionary = Dictionary()

## How often should chunks be saved to disk automatically while chunkmanager is active
enum BACKUP_STRATEGY {
	NONE,			## Do not write automatically to disk
	AT_EXIT, 		## Save only to disk when ChunkManager receives _exit_tree, this is always active for all other strategies
	CONSTANT_RR,	## Constant saving of changed chunks to disk as soon as possible in round robin fashion one chunk per frame
	INTERVAL_RR, 	## Save periodically, defined by backup_interval_seconds in a round robin fashion one chunk at every interval
	INTERVAL, 		## Save all chunks periodically, defined by backup_interval_seconds, all chunks at same time
}

@export_group("Backup")
## How often should chunks be saved to disk automatically while chunkmanager is active
@export var backup_strategy : BACKUP_STRATEGY = BACKUP_STRATEGY.CONSTANT_RR
## Interval for Interval Rr and Interval strategies
@export var backup_interval_seconds = 60.0


func _ready():
	if database_folder == "":
		database_folder = "user://chunkdata"
	if database_uid == "":
		var rando = RandomNumberGenerator.new()
		rando.randomize()
		database_uid = str(str(rando.randi())+OS.get_unique_id()).sha256_text().left(10)
	if database_name == "":
		database_name = "UnNamed"
	if database_format == "":
		database_format = "tscn"
	rebuild_database_folder()


func rebuild_database_folder():
	var global_path = ProjectSettings.globalize_path(database_folder)
	var full_path = global_path+"/"+database_name+"-"+database_uid+"/"
	if not DirAccess.dir_exists_absolute(full_path):
		print("FOLDER %s does not exist at %s" % [database_folder, full_path])
		var error = DirAccess.make_dir_absolute(full_path)
		if error:
			push_error("ChunkManager: CANT CREATE FOLDER %s %s : %s" % [database_folder, full_path, error_string(error)])
	else:
		print("FOLDER %s already exist at %s" % [database_folder, full_path])


func _exit_tree():
	if backup_strategy >= BACKUP_STRATEGY.AT_EXIT:
		save_all_chunks_to_disk()


func save_all_chunks_to_disk():
	for chunk in chunks.values():
		if chunk.data_changed:
			chunk.save_to_disk(get_globalpath(chunk.position))


var frame = 0
func _process(delta):	
	if frame < 1:
		_round_robin_save_chunks_to_disk()
	elif frame < 2:
		_round_robin_keep_hotspots_active()
	elif frame < 3:
		_round_robin_deactivate_and_unload()
	#elif frame < 4:
	#	_round_robin_expand_hotspots()
		
	frame += 1
	if frame > 4:
		frame = 0


var sctd_iterator = 0
func _round_robin_save_chunks_to_disk():
	if chunks.is_empty(): return
	
	var chunk : Chunk = chunks.values()[sctd_iterator]
	if chunk.data_changed:
		chunk.save_to_disk(get_globalpath(chunk.position))
	
	
	sctd_iterator += 1
	if sctd_iterator >= chunks.size():
		sctd_iterator = 0


var kha_iterator = 0
func _round_robin_keep_hotspots_active():
	if hotspots.is_empty(): return
	
	var hotspot : Node3D = hotspots.keys()[kha_iterator]
	var found_chunk = get_chunk_at(hotspot.global_position, true)
	if not found_chunk:
		push_error("ChunkManager: Cannot get chunk at %s" % hotspot.global_position)
		return
	
	if not found_chunk.active:
		activate_chunk(found_chunk)
	
	kha_iterator += 1
	if kha_iterator >= hotspots.size():
		kha_iterator = 0


var deu_iterator = 0
func _round_robin_deactivate_and_unload():
	if chunks.is_empty(): return
	
	if not hotspots.is_empty():
		var chunk : Chunk = chunks.values()[deu_iterator]
		chunk.dist_to_closest_hotspot = 4611686018427387904 # max 64 bit signed int
		for hotspot in hotspots.keys():
			var dist_to_hotspot = Vector3i(chunk.position - half_chunk - (Vector3i(hotspot.global_position)) ).length_squared()
			if chunk.dist_to_closest_hotspot > dist_to_hotspot:
				chunk.dist_to_closest_hotspot = dist_to_hotspot
	
	if chunks.size() > max_chunks:
		var furthest_away = null
		for candidate in chunks.values():
			if not furthest_away or candidate.dist_to_closest_hotspot > furthest_away.dist_to_closest_hotspot:
				furthest_away = candidate
		
		unload_chunk(furthest_away)
	
	if active_chunks.size() > max_active:
		var furthest_away = null
		for candidate in active_chunks.values():
			if not furthest_away or candidate.dist_to_closest_hotspot > furthest_away.dist_to_closest_hotspot:
				furthest_away = candidate
		deactivate_chunk(furthest_away)
	
	deu_iterator += 1
	if deu_iterator >= chunks.size():
		deu_iterator = 0


var eh_iterator = 0
func _round_robin_expand_hotspots():
	if hotspots.is_empty(): return
	
	if chunks.size() > max_chunks: return
	
	var hotspot : Node3D = hotspots.keys()[eh_iterator]
	var found_chunk = get_chunk_at(hotspot.global_position)
	
	eh_iterator += 1
	if eh_iterator >= hotspots.size():
		eh_iterator = 0


func add_hotspot(hotspot : Node3D):
	print("ChunkManager: Adding hotspot")
	if hotspots.get(hotspot):
		push_warning("ChunkManager: Hotspot already exists")
		return
	hotspots[hotspot] = HotspotData.new()
	hotspot.connect("tree_exiting", _on_hotspot_deleted.bind(hotspot))


func remove_hotspot(hotspot : Node3D):
	print("ChunkManager: Removing hotspot")
	var found_hotspot = hotspots.get(hotspot)
	if not found_hotspot:
		push_warning("ChunkManager: Hotspot not found")
		return
	hotspots.erase(found_hotspot)
	hotspot.disconnect("tree_exiting", _on_hotspot_deleted)


## Get the chunk that contains the given point
func get_chunk_at(point : Vector3i, create_missing = true) -> Chunk:
	#print("ChunkManager: getting chunk at %s" % point)
	point -= Vector3i(chunk_size/2,chunk_size/2,chunk_size/2)
	var snapped_position = point.snapped(Vector3i(chunk_size,chunk_size,chunk_size))
	var loaded_chunk = chunks.get(snapped_position)
	if loaded_chunk:
		return loaded_chunk
		
	if FileAccess.file_exists(get_globalpath(snapped_position)):
		var disk_chunk = Chunk.load_from_disk(get_globalpath(snapped_position))
		chunks[snapped_position] = disk_chunk
		emit_signal("chunk_loaded", disk_chunk)
		return disk_chunk
		
	if not create_missing: return null
	
	var new_chunk = Chunk.new()
	new_chunk.name = Chunk.get_filename(chunk_size,snapped_position)
	new_chunk.position = snapped_position
	new_chunk.size = chunk_size
	chunks[snapped_position] = new_chunk
	emit_signal("new_chunk_created", new_chunk)
	emit_signal("chunk_loaded", new_chunk)
	return new_chunk

func activate_chunk(chunk : Chunk):
	active_chunks[chunk.position] = chunk
	chunk.active = true
	emit_signal("chunk_activated", chunk)


func deactivate_chunk(chunk : Chunk):
	active_chunks.erase(chunk.position)
	chunk.active = false
	emit_signal("chunk_deactivated", chunk)


func unload_chunk(chunk : Chunk):
	print("ChunkManager: unloading chunk %s" % chunk)
	if chunk.active:
		deactivate_chunk(chunk)
	chunks.erase(chunk.position)
	emit_signal("chunk_unloaded", chunk)


func _on_update_timer():
	print("foobar!")


func _on_hotspot_deleted(hotspot):
	print("ChunkManager: Received 'hotspot deleted' for %s" % hotspot)


func get_globalpath(pos : Vector3i) -> String:
	return "%s/%s-%s/%s.%s" % [database_folder, database_name, database_uid, Chunk.get_filename(chunk_size, pos), database_format]
