extends VoxelOperation

class_name VoxelOpVisibility



var mat_buffer : PoolIntArray
var vis_buffer : PoolByteArray


func _init(voxel_data, voxel_configuration).(VoxelData.CALC_STATE.VIS, voxel_data, voxel_configuration):
	self.metadata.name = "VoxelOpVisibility"

func to_string ():
	return "[VoxelOpVisibility]"

# Runs in main thread to prepare data
func prepare():
	#print(" - VoxelOpVisibility prepare...")
	mat_buffer = voxel_data.material#.duplicate() dont need to duplicate, we are only reading this
	vis_buffer = voxel_data.visible.duplicate()


# This code is executed in another thread so it can not access voxel_node variable!
func execute(thread_cache : Dictionary):
	#print(" - VoxelOpVisibility executing!")

	match voxel_configuration.accel_mode:
		VoxelConfiguration.ACCEL_MODE.NONE:
			vox_calculate_visibility()
		VoxelConfiguration.ACCEL_MODE.NATIVE:
			vox_calculate_visibility_native()


# This code will be executed in the main thread so acces to voxel_node is ok
func finalize():
	#print("!!! VoxelOpVisibility finalizing...")
	if !vis_buffer:
		push_error("vis_buffer missing!")
	voxel_data.visible = vis_buffer


func vox_calculate_visibility():
		var sx :int = voxel_data.voxel_count.x
		var sy :int = voxel_data.voxel_count.y
		var sz :int = voxel_data.voxel_count.z
		
		# if any dimension is 2 or less then every voxel is going to be visible
		if sx < 3 or sy < 3 or sz < 3:
			for i in range(voxel_data.total_count):
				vis_buffer[i] = true
			return
		
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					var ci = x + y*sx + z*sx*sy
					if x==0 or y == 0 or z == 0 or x == sx-1 or y == sy-1 or z == sz-1:
						vis_buffer[ci] = true
					elif mat_buffer[ci + 1] and mat_buffer[ci - 1] and \
							mat_buffer[ci + sx] and mat_buffer[ci - sx] and \
							mat_buffer[ci + sx*sy] and mat_buffer[ci - sx*sy]:
						vis_buffer[ci] = false
					else:
						vis_buffer[ci] = true	


func vox_calculate_visibility_native():
	var native_worker = VoxelHammer.native_worker
	if not native_worker:
		push_error("VoxelOpVisibility: No native worker found. Falling back to ACCEL_MODE.NONE")
		vox_calculate_visibility()
		return
	
	vis_buffer = native_worker.create_vis(voxel_data.voxel_count, mat_buffer,vis_buffer)

