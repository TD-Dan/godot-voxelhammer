@tool

extends Resource

class_name VoxelConfiguration

signal voxel_configuration_changed(what)


## Material dictionary for voxels. VoxelData.data is referring to these array indices.
@export var materials : Array[Material]:
	set(v):
		materials = v
		emit_signal("voxel_configuration_changed", "materials")

## Voxel reference size in game units. Does not change actual mesh or voxel sizes, but can be used to scale world entities, gravity etc. from one place.
## Voxel to mesh size is alway 1:1 to keep mesh gewneration as fast as possible.
@export_range(0.01, 32.0, 0.01) var voxel_reference_size : float = 1.0:
	set(v):
		voxel_reference_size = v
		emit_signal("voxel_configuration_changed", "voxel_reference_size")

## Mesh generation strategy to use
enum MESH_MODE {
	NONE,
	CUBES,
	FACES
}
## Mesh generation strategy to use
@export var mesh_mode : MESH_MODE = MESH_MODE.FACES:
	set(v):
		mesh_mode = v
		emit_signal("voxel_configuration_changed", "mesh_mode")

## Hardware acceleration mode to use, will fall back to NONE if not available on target system
enum ACCEL_MODE {
	NONE,
	NATIVE,
	GPU,
	GPU_AND_NATIVE
}
## Hardware acceleration mode to use, will fall back to NONE if not available on target system
@export var accel_mode : ACCEL_MODE = ACCEL_MODE.NONE:
	set(v):
		accel_mode = v
		emit_signal("voxel_configuration_changed", "accel_mode")
		

## Threading mode to use, will fall back to NONE if not available on target system
enum THREAD_MODE {
	NONE,
	SIMPLE,
	WORKER_THREAD_POOL
}
## Threading mode to use, will fall back to NONE if not available on target system
@export var thread_mode : THREAD_MODE = THREAD_MODE.NONE:
	set(v):
		thread_mode = v
		emit_signal("voxel_configuration_changed", "thread_mode")

@export_group("Helper tools")

## Select which material index in the materials array to edit
@export var material_to_edit = 0:
	set(nv):		
		material_to_edit = clamp(nv,0,materials.size())

## Doubles the material size by dividing its Triplanar UV1 and UV2 size by two. This is helpfull to circumvent Godot Editors automatic rounding to nearest 0.001 decimals.
@export var double_material_size : bool = false:
	set(nv):
		if nv:
			print("Doubled the uv size of material %s" % material_to_edit)
			double_material_size = false
			materials[material_to_edit].uv1_scale /= 2
			materials[material_to_edit].uv2_scale /= 2

## Halves the material size by doubling its Triplanar UV1 and UV2 size. This is helpfull to circumvent Godot Editors automatic rounding to nearest 0.001 decimals.
@export var half_material_size : bool = false:
	set(nv):
		if nv:
			print("Halved the uv size of material %s" % material_to_edit)
			half_material_size = false
			materials[material_to_edit].uv1_scale *= 2
			materials[material_to_edit].uv2_scale *= 2


func _init():
	pass
	# TODO: test if fixed
	#Hack to circumvent resource loading bug
	materials.clear()
	materials.resize(4)
	materials[0] = preload("../../res/mat_error.tres") as Material
	materials[1] = preload("../../res/mat_uvtest.tres") as Material
	materials[2] = preload("../../res/mat_benchmark.tres") as Material
	materials[3] = preload("../../res/mat_white.tres") as Material


func _to_string():
	return "[VoxelConfiguration:%s]" % get_instance_id()
