@tool

extends VoxelOperation

class_name VoxelOpVisibility

var vis_buffer : PackedByteArray = PackedByteArray()

func _init():
	super("VoxOpVisibility", VoxelOperation.CALCULATION_LEVEL.PRE_MESH)

# This code is potentially executed in another thread!
func run_operation():
	if cancel: return
	if voxel_instance.voxel_data.data_mutex.try_lock():
		calculate_visibility(voxel_instance.voxel_data.data, voxel_instance.voxel_data.size)
		if cancel: return
		voxel_instance.voxel_data.data_mutex.unlock()
		voxel_instance.vis_buffer = vis_buffer
		voxel_instance.call_deferred("notify_visibility_calculated")
	else:
		push_warning("VoxelOpVisibility: Can't get lock on voxel data!")


func calculate_visibility(data : PackedInt64Array, size : Vector3i):
	#print("Calculating visibility...")
	
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
