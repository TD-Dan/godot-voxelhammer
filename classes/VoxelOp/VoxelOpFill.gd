@tool

extends VoxelOperation

class_name VoxelOpFill

var new_value


func _init(fill_value:int):
	super("VoxelOpFill", VoxelOperation.CALCULATION_LEVEL.VOXEL)
	new_value = fill_value

# This code is potentially executed in another thread!
func run_operation():
	#print("%s: run_operation on %s" % [self,voxel_instance])
	var new_data = PackedInt64Array()
	new_data.resize(voxel_instance.voxel_data.get_voxel_count())
	
	if cancel: return
	
	fill(new_data, new_value)
	
	if cancel: return
	
	voxel_instance.voxel_data.data_mutex.lock()
	voxel_instance.voxel_data.data = new_data
	voxel_instance.voxel_data.data_mutex.unlock()
	
	voxel_instance.voxel_data.notify_data_changed.call_deferred()
	voxel_instance.notify_operation_is_ready.call_deferred()

# This code is potentially executed in another thread!
func fill(data : PackedInt64Array, value : int):
	#print("Filling with %s ..." % value)
	
	data.fill(value)
