@tool

extends VoxelOperation

class_name VoxelOpFill

var new_value
var start
var end


func _init(fill_value:int, start=null, end=null):
	super("VoxelOpFill", VoxelOperation.CALCULATION_LEVEL.VOXEL)
	new_value = fill_value
	start = start
	end = end

# This code is potentially executed in another thread!
func run_operation():
	#print("%s: run_operation on %s" % [self,voxel_instance])
	if voxel_instance.voxel_data.data_mutex.try_lock() == OK:
		fill(voxel_instance.voxel_data.data, voxel_instance.voxel_data.size, new_value, start, end)
		voxel_instance.voxel_data.data_mutex.unlock()
		voxel_instance.voxel_data.call_deferred("notify_data_changed")
	else:
		push_warning("VoxelOpFill: Can't get lock on voxel data!")

# This code is potentially executed in another thread!
func fill(data : PackedInt64Array, size : Vector3i, value : int, start = null, end = null):
	#print("Filling with %s ..." % value)
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	if start != null and end != null:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					if x >= start.x and x < end.x and y >= start.y and y < end.y and z >= start.z and z < end.z:
						data[x + y*sx + z*sx*sy] = value
	else:
		data.fill(value)
