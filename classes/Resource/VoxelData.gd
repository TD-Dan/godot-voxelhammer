@tool

extends Resource

class_name VoxelData

#
## Voxel data storage resource
#
# Stores only voxel data and does not know about any other stuff as configurations, meshes or voxel sizes
#
# IMPORTANT! For limitations of godot this class cannot ensure thread safety
# (Resource class type limitation?). Luckily this is also faster because no copies are made.
# Every user of this class MUST call data_mutex.lock() and .unlock() when accessing or editing size and data variables directly


signal voxel_data_changed


@export var size : Vector3i = Vector3i(4,4,4):
	set(nv):
		#print("VoxelData set size: %s" % nv)
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
		
		notify_data_changed.call_deferred()
	get:
		return data # PackedInt64Array(data) # Should make a copy for editing here, but duplication is not working (Might be a Resource related issue)


# All users that modify this object need to call data_mutex.lock() and .unlock() to ensure thread safety
var data_mutex = Mutex.new()


func _init(fill_with = null):
	#print("%s: _init(%s)" % [self,fill_with])
	#print("%s: data size: %s" % [self,data.size()])
	if fill_with:
		clear(fill_with)


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


# Clears all voxel data to value
func clear(value=0):
	#var run_start_us = Time.get_ticks_usec()
	
	data_mutex.lock()
	var count = get_voxel_count()
	if data.size() != count:
		data.resize(count)
	data.fill(value)
	data_mutex.unlock()
	
	#var delta_time_us = Time.get_ticks_usec() - run_start_us
	#print("%s: clear took %s seconds" % [self, delta_time_us/1000000.0])
	
	notify_data_changed()


func notify_data_changed():
	#print("%s: _notify_data_changed" % [self])
	emit_signal("voxel_data_changed")
	notify_property_list_changed()
