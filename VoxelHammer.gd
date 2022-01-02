tool

extends Node

# Global settings for VoxelHammer Plugin

signal show_debug_gizmos_changed(value)

export(Resource) var default_configuration = preload("res://addons/voxel_hammer/default_voxel_configuration.tres")

export var use_camera_for_priority = true
export var show_debug_gizmos = false setget _set_show_debug_gizmos

var native_rust_worker_script = preload("res://addons/voxel_hammer/gdnative/NativeWorkerRust.gdns")
var native_worker = null

func _set_show_debug_gizmos(nv):
	show_debug_gizmos = nv
	emit_signal("show_debug_gizmos_changed", show_debug_gizmos)

func _enter_tree():
	native_worker = native_rust_worker_script.new()
	add_child(native_worker)
