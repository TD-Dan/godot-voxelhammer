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
		
		data_mutex.lock()
		data.resize(get_voxel_count())
		data_mutex.unlock()
	
		clear()


# Voxel data, get is unsafe for threading without ensuring single access by user
@export var data : PackedInt64Array = PackedInt64Array():
	set(nv):
		data_mutex.lock()
		data = nv
		data_mutex.unlock()
		
		notify_data_changed()
	get:
		return data # PackedInt64Array(data) # Should make a copy for editing here, but duplication is not working (Might be a Resource related issue)

var data_mutex = Mutex.new()

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
	data_mutex.lock()
	data.fill(0)
	data_mutex.unlock()
	notify_data_changed()


func notify_data_changed():
	print("%s: _notify_data_changed" % [self])
	emit_signal("voxel_data_changed")
	notify_property_list_changed()
