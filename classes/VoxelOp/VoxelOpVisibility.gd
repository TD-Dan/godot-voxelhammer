@tool

extends VoxelOperation

class_name VoxelOpVisibility

var vis_buffer : PackedByteArray = PackedByteArray()

func _init():
	super("VoxOpVisibility", VoxelOperation.CALCULATION_LEVEL.PRE_MESH)

# This code is potentially executed in another thread!
func run_operation():
	
	#var run_start_us = Time.get_ticks_usec()
	
	voxel_instance.voxel_data.data_mutex.lock()
	var local_data_buffer = voxel_instance.voxel_data.data.duplicate()
	var local_buffer_dimensions = voxel_instance.voxel_data.size
	voxel_instance.voxel_data.data_mutex.unlock()
	
	#var delta_time_us = Time.get_ticks_usec() - run_start_us
	#print("%s: data duplication took %s seconds" % [self, delta_time_us/1000000.0])
	
	if cancel: return
	
	calculate_visibility(local_data_buffer, local_buffer_dimensions)
	
	if cancel: return
	
	voxel_instance.data_buffer_mutex.lock()
	voxel_instance.data_buffer = local_data_buffer
	voxel_instance.data_buffer_dimensions = local_buffer_dimensions
	voxel_instance.vis_buffer = vis_buffer
	voxel_instance.data_buffer_mutex.unlock()
	
	voxel_instance.call_deferred("notify_visibility_calculated")


func calculate_visibility(data : PackedInt64Array, size : Vector3i):
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	vis_buffer.resize(data.size())
	
	for z in range(sz):
		for y in range(sy):
			if cancel: return
			for x in range(sx):
				var ci = x + y*sx + z*sx*sy
				if !data[ci]:
					vis_buffer[ci] = 0 #invisible
				elif x==0 or y == 0 or z == 0 or x == sx-1 or y == sy-1 or z == sz-1:
					vis_buffer[ci] = 1 #visible
				elif data[ci + 1] and data[ci - 1] and \
						data[ci + sx] and data[ci - sx] and \
						data[ci + sx*sy] and data[ci - sx*sy]:
					vis_buffer[ci] = 0 #invisible
				else:
					vis_buffer[ci] = 1 #visible
