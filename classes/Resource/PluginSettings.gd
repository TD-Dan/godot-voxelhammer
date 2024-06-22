@tool

extends Resource

class_name PluginSettings


signal player_node_group_changed()


## Change this if plugin is located somewhere else than its default location.
@export_dir var plugin_directory = "res://addons/godot-voxelhammer/"

## Node(s) from this group are used as player(s). Used for terrain and mesh generation priorities so that everything around player(s) is calculated first.
@export var player_node_group : String:
	set(nv):
		player_node_group = nv
		player_node_group_changed.emit()


func _to_string():
	return "[PluginSettings:%s]" % get_instance_id()
