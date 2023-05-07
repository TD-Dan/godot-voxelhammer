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

@export var chunk_size : int = 16

@export_group("Database File")
@export var database_folder : String = ""
@export var database_uid : String = ""
@export var database_name : String = ""
@export var database_format : String = ""
@export var create_database : bool = false:
	set(nv): rebuild_database_folder()

@export_group("Chunk generation")
@export var max_chunks : int = 50
@export var max_active : int = 20

@export var thread_mode : VoxelConfiguration.THREAD_MODE = VoxelConfiguration.THREAD_MODE.NONE


var chunks : Dictionary = {}
var active_chunks : Dictionary = {}
var changed_chunks : Dictionary = {}

## Hotspots keep chunks active around them
var hotspots : Dictionary = Dictionary()


func _ready():
	if database_folder == "":
		database_folder = "user://chunkdata"
	if database_uid == "":
		var rando = RandomNumberGenerator.new()
		rando.randomize()
		database_uid = str(str(rando.randi())+OS.get_unique_id()).sha256_text().left(10)
	if database_name == "":
		database_name = "Unnamed"
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
		print("FOLDER %s exist at %s" % [database_folder, full_path])

func _exit_tree():
	for chunk in chunks.values():
		chunk.save_to_disk("%s/%s-%s/%s.%s" % [database_folder, database_name, database_uid, chunk.get_filename(), database_format])
	
	
var frame = 0
func _process(delta):	
	if frame < 1:
		_round_robin_save_chunks_to_disk()
	elif frame < 2:
		_round_robin_keep_hotspots_active()
	elif frame < 3:
		_round_robin_expand_hotspots()
		
	frame += 1
	if frame > 10:
		frame = 0


var sctd_iterator = 0
func _round_robin_save_chunks_to_disk():
	if chunks.is_empty(): return
	
	var chunk = chunks.values()[sctd_iterator]
	#print(sctd_iterator)
	
	sctd_iterator += 1
	if sctd_iterator >= chunks.size():
		sctd_iterator = 0


var kha_iterator = 0
func _round_robin_keep_hotspots_active():
	if hotspots.is_empty(): return
	
	var hotspot : Node3D = hotspots.keys()[kha_iterator]
	var found_chunk = get_chunk_at(hotspot.global_position, false)
	
	if not found_chunk.active:
		active_chunks[found_chunk.position] = found_chunk
		found_chunk.active = true
		emit_signal("chunk_activated", found_chunk)
	
	kha_iterator += 1
	if kha_iterator >= hotspots.size():
		kha_iterator = 0


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
	hotspots[hotspot] = hotspot.global_position
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
	var index_position = point.snapped(Vector3i(chunk_size,chunk_size,chunk_size))
	var found_chunk = chunks.get(index_position)
	if found_chunk:
		return found_chunk
	else:
		if not create_missing: return null
		
		var new_chunk = Chunk.new()
		new_chunk.position = index_position
		chunks[index_position] = new_chunk
		emit_signal("new_chunk_created", new_chunk)
		emit_signal("chunk_loaded", new_chunk)
		return new_chunk


func _on_update_timer():
	print("foobar!")


func _on_hotspot_deleted(hotspot):
	print("ChunkManager: Received 'hotspot deleted' for %s" % hotspot)
