@tool

extends Node

class_name Streamable

## Allows parent Node to be streamed by DatabaseStreamer
##
## + provides a stream_data_id to match data with database
## + stores what variables to persist from parent node, set by parent script or user via editor
## + signals changes to listeners
## ! does not need to know anything about parent or DatabaseStreamer


## Something in the Streamables parent and or its children has changed
signal stream_data_changed(data_stream : Streamable)

## Parent and streamable are removed from scene tree
signal stream_exitted(data_stream : Streamable)


## Unique id used to match database content to this node. Leave empty to generate automatically. If database already has entry with this id, all data will be loaded from it.
@export var stream_data_id : String = ""

## Node contents has been changed and should be streamed to database
var has_unwritten_data = false


func notify_stream_data_changed():
	#print("Received notification")
	has_unwritten_data = true
	stream_data_changed.emit(self)


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
