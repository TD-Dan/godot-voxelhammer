@tool

extends Resource

class_name VoxelData

#
## Voxel data storage resource
#
# Stores only voxel data and does not know about any other stuff as configurations,meshes or voxel sizes


signal voxel_data_changed

@export var size : Vector3i = Vector3i(8,8,8):
	set(nv):
		if nv.x == 0 or nv.y == 0 or nv.z == 0:
			push_error("VoxelData size cannot be zero: %s. -> Ignored" % nv)
			return
		
		size = nv
		
		data.resize(get_voxel_count())
	
		clear()
		
		#notify_data_changed()


@export var data : PackedInt64Array = PackedInt64Array():
	set(nv):
		data_mutex.lock()
		data = nv
		data_mutex.unlock()
		
		#notify_data_changed()

var data_mutex = Mutex.new()

func get_voxel_count():
	return size.x*size.y*size.z

# Clears all voxel data to zero
func clear():
	data_mutex.lock()
	data.fill(0)
	data_mutex.unlock()
	emit_signal("voxel_data_changed")
	notify_property_list_changed()

func notify_data_changed():
	emit_signal("voxel_data_changed")
	notify_property_list_changed()
