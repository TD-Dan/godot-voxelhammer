@tool

extends Node

# Global settings for VoxelHammer Plugin

signal show_debug_gizmos_changed(value)

@export var plugin_directory = "res://addons/godot-voxelhammer/"

@export var default_configuration_path = "res://addons/godot-voxelhammer/res/default_voxel_configuration.tres"
@export var default_configuration : Resource

@export var show_debug_gizmos = false:
	set(v):
		show_debug_gizmos = v
		emit_signal("show_debug_gizmos_changed", show_debug_gizmos)

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
	
	#WorkerThreadPool
	# possibly add push_warning("VoxelHammer: Project WorkerThreadPool size is -1, which causes stuttering with this plugin. It has been set to number of CPU cores")
	#threading/worker_pool/max_threads
	
	#TODO move gdnative to GD4 GDExtension
	#if File.new().file_exists("res://addons/TallDwarf/VoxelHammer-NativeRust/gdnative/NativeWorkerRust.gdns"):
	#	print("VoxelHammer found VoxelHammer-NativeRust plugin")
	#	native_rust_worker_script = load("res://addons/TallDwarf/VoxelHammer-NativeRust/gdnative/NativeWorkerRust.gdns")
	#	native_worker = native_rust_worker_script.new()
	#	add_child(native_worker)
	print("VoxelHammer loaded")
