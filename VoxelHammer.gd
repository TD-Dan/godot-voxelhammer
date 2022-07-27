@tool

extends Node

# Global settings for VoxelHammer Plugin

signal show_debug_gizmos_changed(value)

@export var default_configuration : Resource = preload("./res/default_voxel_configuration.tres")

@export var show_debug_gizmos = false:
	set(v):
		show_debug_gizmos = v
		emit_signal("show_debug_gizmos_changed", show_debug_gizmos)

var native_rust_worker_script = null
var native_worker = null


func _enter_tree():
	if File.new().file_exists("res://addons/TallDwarf/VoxelHammer-NativeRust/gdnative/NativeWorkerRust.gdns"):
		print("VoxelHammer found VoxelHammer-NativeRust plugin")
		native_rust_worker_script = load("res://addons/TallDwarf/VoxelHammer-NativeRust/gdnative/NativeWorkerRust.gdns")
		native_worker = native_rust_worker_script.new()
		add_child(native_worker)
