@tool

extends Resource

class_name VoxelConfiguration

signal voxel_configuration_changed(what)


@export var materials : Array[Material]:
	set(v):
		materials = v
		emit_signal("voxel_configuration_changed", "materials")

# Voxel size in game units
@export_range(0.01, 32.0, 0.01) var voxel_base_size : float = 1.0:
	set(v):
		voxel_base_size = v
		emit_signal("voxel_configuration_changed", "voxel_base_size")

# Mesh generation mode. Use FAST, others are used for development purposes
enum MESH_MODE {
	NONE,
	CUBES,
	FACES,
	FAST,
}
@export var mesh_mode : MESH_MODE = MESH_MODE.FAST:
	set(v):
		mesh_mode = v
		emit_signal("voxel_configuration_changed", "mesh_mode")

# Select hardware acceleration mode to use, will fall back to NONE if not available on target system
enum ACCEL_MODE {
	NONE,
	NATIVE,
	GPU,
	GPU_AND_NATIVE
}
@export var accel_mode : ACCEL_MODE = ACCEL_MODE.NONE:
	set(v):
		accel_mode = v
		emit_signal("voxel_configuration_changed", "accel_mode")
