@tool

extends Resource

class_name VoxelData

#
## Voxel data storage resource
#
# Stores only voxel data and does not know about any other stuff as configurations,meshes or voxel sizes
#
# Modification of data variable only by replacing whole array


signal voxel_data_changed

@export var size : Vector3i = Vector3i(8,8,8):
	set(nv):
		if nv.x <= 0 or nv.y <= 0 or nv.z <= 0:
			push_error("VoxelData size cannot be zero or negative: %s. -> Ignored" % nv)
			return
		
		size = nv
		
		data.resize(get_voxel_count())
	
		clear()


# Voxel data, cannot be directly modified, use duplicate buffers and replace whole data as whole or use set_voxel()
@export var data : PackedInt64Array = PackedInt64Array():
	set(nv):
		_data_mutex.lock()
		data = nv
		_data_mutex.unlock()
		
		_notify_data_changed()
	get:
		return data.duplicate()

var _data_mutex = Mutex.new()

func _to_string():
	return "[VoxelData:%s]" % get_instance_id()
	
func get_voxel_count():
	return size.x*size.y*size.z

func xyz_to_index(x:int,y:int,z:int) -> int: return x + y*size.x + z*size.x*size.y
func vector3i_to_index(vec : Vector3i) -> int: return vec.x + vec.y*size.x + vec.z*size.x*size.y
func index_to_vector3i(i:int) -> Vector3i: # HOX! Untested!
	var ret : Vector3i = Vector3i()
	ret.x = i / (size.y * size.z)
	var w = i % (size.y * size.z)
	ret.y = w / size.z
	ret.z = w % size.z
	return ret

# Clears all voxel data to zero
func clear():
	_data_mutex.lock()
	data.fill(0)
	_data_mutex.unlock()
	_notify_data_changed()


func _notify_data_changed():
	#print("%s: notify_data_changed" % [self])
	emit_signal("voxel_data_changed")
	notify_property_list_changed()
