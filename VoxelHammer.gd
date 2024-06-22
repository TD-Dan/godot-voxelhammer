@tool

extends Node

## Global singleton and settings for VoxelHammer Plugin


signal show_debug_gizmos_changed(value)


@export var plugin_directory = "res://addons/godot-voxelhammer/"

@export var default_configuration_path = "res://addons/godot-voxelhammer/res/default_voxel_configuration.tres"
@export var default_configuration : Resource

@export var show_debug_gizmos = false:
	set(v):
		show_debug_gizmos = v
		emit_signal("show_debug_gizmos_changed", show_debug_gizmos)



var task_server_plugin = null

var native_rust_worker_script = null
var native_worker = null


# Guard agains GODOT 4.0 bug on threaded access, see comment on VoxelOpCreateMesh.gd
var surface_tool_guard_mutex = Mutex.new()


func _enter_tree():
	print("VoxelHammer loading")
	
	if ProjectSettings.has_setting("voxelhammer/plugin_directory"):
		plugin_directory = ProjectSettings.get_setting("voxelhammer/plugin_directory")
	else:
		ProjectSettings.set_setting("voxelhammer/plugin_directory", plugin_directory)
	
	if ProjectSettings.has_setting("voxelhammer/default_configuration_path"):
		default_configuration_path = ProjectSettings.get_setting("voxelhammer/default_configuration_path")
	else:
		ProjectSettings.set_setting("voxelhammer/default_configuration_path", default_configuration_path)
	default_configuration = load(default_configuration_path)
	
	if ProjectSettings.has_setting("voxelhammer/show_debug_gizmos"):
		show_debug_gizmos = ProjectSettings.get_setting("voxelhammer/show_debug_gizmos")
	else:
		ProjectSettings.set_setting("voxelhammer/show_debug_gizmos", show_debug_gizmos)
	
	
	var system_threads = ProjectSettings.get_setting("threading/worker_pool/use_system_threads_for_low_priority_tasks")
	if system_threads:
		push_warning("VoxelHammer: Setting threading/worker_pool/use_system_threads_for_low_priority_tasks to false: Will cause frame stuttering if used.")
		ProjectSettings.set_setting("threading/worker_pool/use_system_threads_for_low_priority_tasks", false)
	
	
	#TODO move gdnative to GD4 GDExtension
	#if File.new().file_exists("res://addons/TallDwarf/VoxelHammer-NativeRust/gdnative/NativeWorkerRust.gdns"):
	#	print("VoxelHammer found VoxelHammer-NativeRust plugin")
	#	native_rust_worker_script = load("res://addons/TallDwarf/VoxelHammer-NativeRust/gdnative/NativeWorkerRust.gdns")
	#	native_worker = native_rust_worker_script.new()
	#	add_child(native_worker)
	
	_post_ready.call_deferred()


func _post_ready():
	# If TaskServer plugin is present connect to it
	task_server_plugin = Engine.get_main_loop().root.get_node_or_null("TaskServer")
	
	if task_server_plugin:
		print("VoxelHammer: Found TaskServer plugin! Integrating...")
	else:
		push_warning("%s: (OPTIONAL) TaskServer plugin not found. Some advanced features will not be available. Taskserver is available from 'github.com/TD-Dan/godot_task_server'." % self)
		if default_configuration.thread_mode == VoxelConfiguration.THREAD_MODE.TASK_SERVER:
			push_warning("%s: TaskServer not available: Falling back to simple threaded execution.")
			default_configuration.thread_mode = VoxelConfiguration.THREAD_MODE.WORKER_THREAD_POOL
	
	
	print("VoxelHammer loaded")
