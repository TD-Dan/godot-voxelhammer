@tool

extends Resource

class_name VoxelData

#
## Dynamic Voxel data storage resource
#
# Other classes can add their own data into

signal voxels_changed
signal persistent_data_changed(what)
signal runtime_data_changed(what)

@export var size = Vector3i(8,8,8):
	set(nv):
		if nv.x == 0 or nv.y == 0 or nv.z == 0:
			push_error("VoxelData size cannot be zero: %s. -> Ignored" % nv)
			print("VoxelData size cannot be zero: %s." % nv)
			return
		
		size = nv
		
		print("Setting VoxelData size to: %s" % nv)
		
		var total_size = nv.x * nv.y * nv.z
		print("here")
		voxels_mutex.lock()
		voxels.clear()
		voxels.resize(total_size)
		voxels_mutex.unlock()
		
		print("Testing voxel data [0] after resize = " + str(voxels[0]))
		
		notify_voxels_changed()
		notify_property_list_changed()

# Voxel data
@export var voxels : Array[int]
# TODO: test if faster with PackedInt64Array
#@export var voxels : PackedInt64Array

# Extra persistent data
# Access from other class with persistent_data_dict["Classname-variable"] = data_to_store
@export var persistent_data_dict : Dictionary = Dictionary()

# Extra runtime data
# Access from other class with runtime_data_dict["Classname-variable"] = data_to_store
var runtime_data_dict : Dictionary = Dictionary()

# Mutex for multithreaded editing
var voxels_mutex = Mutex.new()

func notify_voxels_changed():
	emit_signal("voxels_changed")


func notify_persistent_data_changed(what:String):
	emit_signal("persistent_data_changed", what)


func notify_runtime_data_changed(what:String):
	emit_signal("runtime_data_changed", what)
