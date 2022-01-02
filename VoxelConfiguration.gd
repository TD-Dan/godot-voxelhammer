tool

extends Resource

class_name VoxelConfiguration

signal voxel_configuration_changed(what)


export(Array, Material) var materials setget _set_vox_materials

# Voxel size in game units
export(float, 0.01, 32.0, 0.01) var voxel_base_size : float = 1.0 setget _set_voxel_size

enum MESH_MODE {
	NONE,
	CUBES,
	FACES,
	FAST,
}

export(MESH_MODE) var mesh_mode = MESH_MODE.FACES setget _set_mesh_mode

enum ACCEL_MODE {
	NONE,
	NATIVE,
	GPU,
	GPU_AND_NATIVE
}
export(ACCEL_MODE) var accel_mode = ACCEL_MODE.NONE setget _set_accel_mode

func _set_vox_materials(new_value):
	materials = new_value
	emit_signal("voxel_configuration_changed", "materials")

func _set_voxel_size(new_value):
	voxel_base_size = floor(new_value)
	emit_signal("voxel_configuration_changed", "voxel_base_size")

func _set_mesh_mode(new_value):
	mesh_mode = new_value
	emit_signal("voxel_configuration_changed", "mesh_mode")
	
func _set_accel_mode(new_value):
	accel_mode = new_value
	emit_signal("voxel_configuration_changed", "accel_mode")
