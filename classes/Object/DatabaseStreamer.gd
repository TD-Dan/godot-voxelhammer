@tool

extends Node

class_name DatabaseStreamer

## Streams node data between memory and a file database
##
## + Save and load data from local folder using Streamable.stream_data_id as filename
## + Backup data automatically according to chosen strategy
## ! Does not know and does not need to know about contents
## ! Does not create new objects on its own: needs an existing streamable for connecting to existing data
##
## ! Either Streamables or DatabaseStreamer might get deleted first so both cases need to be accounted for


## Group name of objects to stream
@export var stream_group = "all_streamables"


@export_group("Database Location")
## database base folder, usually "user://somefolder"
@export var database_location : String = ""
## unique id to distinguish for different saves/users, even if they use same database name
@export var database_uid : String = ""
## Human readable part of database name
@export var database_name : String = ""
## Savefile format, SCN for binary savefiles (fast), TSCN for text scene files for debugging (slow)
@export_enum("scn","tscn") var database_format : String = ""


@export_group("Threading")
## Wether to utilize threading for file read/write
@export var use_threads : bool = false:
	set(nv):
		use_threads = nv


@export_group("Backup")
## How often should streamables be automatically saved to database
enum BACKUP_STRATEGY {
	NONE,			## Do not write automatically to disk
	AT_EXIT, 		## Save only to disk when ChunkManager receives _exit_tree, this is also always active for all other strategies
	INTERVAL, 		## Save all chunks periodically, defined by backup_interval_seconds, all chunks at same time
	INTERVAL_RR, 	## Save periodically, defined by backup_interval_seconds in a round robin fashion one Streamable at every interval
	INSTANT,		## Instant saving of changed data to database as soon as changes are made
	INSTANT_RR,		## Instant saving of changed data to database as soon as changes are made one streamable at a time
}
## How often should chunks be saved to disk automatically while chunkmanager is active
@export var backup_strategy : BACKUP_STRATEGY = BACKUP_STRATEGY.INTERVAL_RR
## Interval for Interval Rr and Interval strategies
@export var backup_interval_seconds = 60.0


@export_group("Helpers")
## Create database folder if it does not exist
## Note to not try: this *could* be made to happen automatically when any database_* variables changes, but in editor this will create all folders from editing the prompts like : "d", "da", "dat", "data" ... as godot refreshes variable after every edit
@export var create_database_folder : bool = false:
	set(nv): _rebuild_database_folder()
## Helper to open the user folder in OS
@export var open_user_folder : bool = false:
	set(nv):
		OS.shell_open(ProjectSettings.globalize_path("user://"))


func _ready():
	if database_location == "":
		database_location = "user://chunkdata"
	if database_uid == "":
		var rando = RandomNumberGenerator.new()
		rando.randomize()
		database_uid = str(str(rando.randi())+OS.get_unique_id()).sha256_text().left(10)
	if database_name == "":
		database_name = "Unnamed"
	if database_format == "":
		database_format = "scn"
		
	if Engine.is_editor_hint():
		return
	
	_rebuild_database_folder()
	_connect_to_streamables_in_group()
	_connect_to_monitor_tree.call_deferred()
	
	load_all_from_disk()


func _connect_to_streamables_in_group():
	var stream_nodes = get_tree().get_nodes_in_group(stream_group)
	for node : Streamable in stream_nodes:
		_connect_to_streamable(node)


func _connect_to_monitor_tree():
	if not get_tree().node_added.is_connected(_on_node_added_to_tree):
		get_tree().node_added.connect(_on_node_added_to_tree)


func _exit_tree():
	if Engine.is_editor_hint():
		return
	
	if backup_strategy >= BACKUP_STRATEGY.AT_EXIT:
		save_all_to_disk()


var delta_counter = 0.0
func _process(delta):
	if Engine.is_editor_hint():
		return
	
	delta_counter += delta
	if delta_counter > backup_interval_seconds:
		delta_counter -= backup_interval_seconds
		
		match backup_strategy:
			BACKUP_STRATEGY.INTERVAL:
				save_all_to_disk()
			#BACKUP_STRATEGY.INTERVAL_RR:
			#	_round_robin_save_changes()


## Load all streamables from disk
func load_all_from_disk():
	if Engine.is_editor_hint():
		return
	
	print("%s: Loading all" % self)
	for streamable in get_tree().get_nodes_in_group(stream_group):
		load_from_disk(streamable)


## Save all changes to disk
func save_all_to_disk():
	if Engine.is_editor_hint():
		return
	
	print("%s: Saving all" % self)
	for streamable in get_tree().get_nodes_in_group(stream_group):
		save_to_disk(streamable)


var rr_iterator = 0
func _round_robin_save_changes():
	print("%s: round robing saving" % self)
	pass


func get_stream_full_filename_and_path(stream_id : String):
	var global_path = ProjectSettings.globalize_path(database_location)
	var full_path = global_path+"/"+database_name+"-"+database_uid+"/"
	var full_filename = full_path + stream_id + "." + database_format
	return full_filename
	

## Save parent of streamable and parents children to disk
func save_to_disk(data_stream : Streamable):
	if Engine.is_editor_hint(): return
	if data_stream.disable: return
	
	if not data_stream.has_unwritten_data():
		print("%s: Skipping saving %s: no changes." % [self, data_stream])
		return
	
	var completefilepath = get_stream_full_filename_and_path(data_stream.stream_data_id)
	print("%s: Saving %s to disk as %s" % [self, data_stream, completefilepath])
	
	var packet = PackedScene.new()
	var parent_node = data_stream.get_parent()
	
	# Include children owned by editor to the savefile, exclude the Streamable
	# using dictionary instead of metadata because metadata gets saved in the file
	var old_parents = Dictionary()
	for child in parent_node.get_children():
		if child is Streamable:
			old_parents[child] = child.owner
			child.owner = null
		elif child.owner != parent_node:
			old_parents[child] = child.owner
			child.owner = parent_node
	
	var error = packet.pack(parent_node)
	
	# Return modified children owners to old values
	for child in old_parents.keys():
		if old_parents[child] != null:
			child.owner = old_parents[child]
	
	if error:
		push_error("%s: Packing for saving failed: %s" % [self, error_string(error)])
		data_stream.disable = true
		return
	
	error = ResourceSaver.save(packet, completefilepath, ResourceSaver.FLAG_COMPRESS)
	if error:
		push_error("%s: Chunk save to %s failed: %s" % [self, completefilepath, error_string(error)])
		data_stream.disable = true
		return
	
	data_stream.notify_stream_has_been_saved()


## Load parent of streamable from disk and replace 
func load_from_disk(data_stream : Streamable):
	if Engine.is_editor_hint(): return
	if data_stream.disable: return
	
	if data_stream.has_unwritten_data():
		push_warning("Discarding changes by loading from disk!")
	
	if not data_stream.stream_data_id:
		print("%s : %s has empty stream_data_id" % [self, data_stream])
		data_stream.disable = true
		return
	var completefilepath = get_stream_full_filename_and_path(data_stream.stream_data_id)
	if not FileAccess.file_exists(completefilepath):
		print("%s : %s, No file named %s exists, skipping stream load." % [self, data_stream, completefilepath])
		
		save_to_disk.call_deferred(data_stream)
		return
	
	print("Loading from disk : %s : %s" % [data_stream.stream_data_id, completefilepath])
	var load_packet : PackedScene = ResourceLoader.load(completefilepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	var parent = data_stream.get_parent()
	
	# move Streamable to new parent
	parent.remove_child(data_stream)
	
	for child in parent.get_children():
		child.queue_free()
	
	var new_node = load_packet.instantiate()
	
	new_node.add_child(data_stream)
	
	# Give time for children to be free themselves
	_post_load.call_deferred(data_stream, parent, new_node)


# Finalize loading
func _post_load(data_stream : Streamable, parent, new_node):
	
	parent.replace_by(new_node, true)


func _rebuild_database_folder():
	if Engine.is_editor_hint():
		return
	
	var global_path = ProjectSettings.globalize_path(database_location)
	if not DirAccess.dir_exists_absolute(global_path):
		print("%s:Creating database root at %s" % [self, global_path])
		var error = DirAccess.make_dir_absolute(global_path)
		if error:
			push_error("%s: CANT CREATE DATABASE ROOT %s, ERROR: %s" % [self, global_path, error_string(error)])
		
	var full_path = global_path+"/"+database_name+"-"+database_uid+"/"
	if not DirAccess.dir_exists_absolute(full_path):
		print("%s:Creating FOLDER %s at %s" % [self, database_location, full_path])
		var error = DirAccess.make_dir_absolute(full_path)
		if error:
			push_error("%s: CANT CREATE FOLDER %s %s : %s" % [self, database_location, full_path, error_string(error)])
	else:
		print("%s: Found chunkdata %s at %s" % [self, database_location, full_path])


func _connect_to_streamable(data_stream : Streamable):
	if not data_stream.stream_data_changed.is_connected(_on_stream_data_changed):
		data_stream.stream_data_changed.connect(_on_stream_data_changed)
	if not data_stream.stream_exitted.is_connected(_on_stream_exitted):
		data_stream.stream_exitted.connect(_on_stream_exitted)


func _on_stream_data_changed(data_stream : Streamable):
	if backup_strategy == BACKUP_STRATEGY.INSTANT:
		save_to_disk(data_stream)


func _on_stream_exitted(data_stream : Streamable):
	if backup_strategy >= BACKUP_STRATEGY.AT_EXIT:
		save_to_disk(data_stream)


func _on_node_added_to_tree(node: Node):
	if node.is_in_group(stream_group) and node is Streamable:
		var data_stream : Streamable = node
		print("found new Streamable in group")
		_connect_to_streamable(data_stream)
		#if node.
		#	load_from_disk(node)
