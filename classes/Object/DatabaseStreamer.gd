@tool

extends Node

class_name DatabaseStreamer

## Streams node data between memory and a file database
##
## + Save and load data from local folder using Streamable.stream_data_id as filename
## + Backup data automatically according to chosen strategy
## ! Does not know and does not need to know about contents
## ! Does not crete new objects on its own: needs an existing streamable for connecting to existing data


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
	set(nv): rebuild_database_folder()
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
	rebuild_database_folder()
	
	_post_ready.call_deferred()

func _post_ready():
	connect_to_streamables_in_stream_group()
	
	var stream_nodes = get_tree().get_nodes_in_group(stream_group)
	for node : Streamable in stream_nodes:
		load_from_disk(node)


func connect_to_streamables_in_stream_group():
	var stream_nodes = get_tree().get_nodes_in_group(stream_group)
	
	for node : Streamable in stream_nodes:
		node.stream_data_changed.connect(_on_stream_data_changed.bind(node))


func _on_stream_data_changed(data : Streamable):
	if backup_strategy == BACKUP_STRATEGY.INSTANT:
		save_to_disk(data)


func rebuild_database_folder():
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


func _exit_tree():
	if backup_strategy >= BACKUP_STRATEGY.AT_EXIT:
		save_all_changes()


var delta_counter = 0.0
func _process(delta):
	if Engine.is_editor_hint():
		return
	
	delta_counter += delta
	if delta_counter > backup_interval_seconds:
		delta_counter -= backup_interval_seconds
		
		match backup_strategy:
			BACKUP_STRATEGY.INTERVAL:
				save_all_changes()
			BACKUP_STRATEGY.INTERVAL_RR:
				_round_robin_save_changes()


## Save all changes to disk
func save_all_changes():
	print("%s: saving all" % self)
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
	

## Save all persistent_data to disk
func save_to_disk(data : Streamable):
	var completefilepath = get_stream_full_filename_and_path(data.stream_data_id)
	print("%s: Saving Streamable %s to disk as %s" % [self, data, completefilepath])
	
	var packet = PackedScene.new()
	var save_node = data.get_parent()
	var error = packet.pack(save_node)
	if error:
		push_error("%s: Packing for saving failed: %s" % [self, error_string(error)])
		return
	error = ResourceSaver.save(packet, completefilepath, ResourceSaver.FLAG_COMPRESS)
	if error:
		push_error("%s: Chunk save to %s failed: %s" % [self, completefilepath, error_string(error)])
		return


## Load all persistent_data from disk and return a Chunk containing it
func load_from_disk(data : Streamable):
	if not data.stream_data_id:
		print("%s : %s has empty stream_data_id" % [self, data])
		return
	var completefilepath = get_stream_full_filename_and_path(data.stream_data_id)
	if not FileAccess.file_exists(completefilepath):
		print("%s : %s, No file named %s exists, skipping stream load." % [self, data, completefilepath])
		return
	
	print("Loading from disk : %s : %s" % [data.stream_data_id, completefilepath])
	#var load_packet : PackedScene = ResourceLoader.load(completefilepath, "", ResourceLoader.CACHE_MODE_IGNORE)
	
