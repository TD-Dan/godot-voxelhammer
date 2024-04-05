@tool

extends Node

class_name Streamable

## Allows parent Node to be streamed by DatabaseStreamer
##
## + Acts as an adapter between DatabaseStreamer and Nodes
## + provides a stream_data_id to match data with database
##
## ! does not need to know anything about parent, files or DatabaseStreamers


## Emitted when something in the Streamables parent and or its children has changed
signal stream_data_changed(data_stream : Streamable)

## Emitted when streamable is removed from scene tree
signal stream_exitted(data_stream : Streamable)


## Unique id used to match database content to this node. Leave empty to generate automatically. If database already has entry with this id, all data will be loaded from it.
@export var stream_data_id : String = ""


var _has_unwritten_data = false
## Parent or its children content has been changed and should be streamed to database according to 
func has_unwritten_data():
	return _has_unwritten_data


## Streaming can be disabled f.ex. if critical errors are encountered
var disable = false:
	set(nv):
		disable = nv
		if disable:
			push_error("%s is disabled!" % self)


## Tell the Streamable that some variable in its parent or parents children have changed
func notify_stream_data_changed():
	#print("Received notification")
	_has_unwritten_data = true
	stream_data_changed.emit(self)


## Tell the Streamable that it has been saved to file
func notify_stream_has_been_saved():
	_has_unwritten_data = false


func _ready():
	if get_groups().is_empty():
		add_to_group("all_streamables",true)
	
	_post_ready.call_deferred()


func _post_ready():
	if stream_data_id == "" or not stream_data_id:
		stream_data_id = str(self.get_instance_id())
	
	if Engine.is_editor_hint() and owner == null:
		owner = get_tree().edited_scene_root


func _exit_tree():
	#print("%s: Streamable _exit_tree" % self)
	stream_exitted.emit(self)
