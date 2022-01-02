extends VoxelOperation

class_name VoxelOpFill

var new_material :int
var new_smooth :int
var start
var end

var mat_buffer : PoolIntArray
var smooth_buffer : PoolByteArray

func _init(voxel_data, voxel_configuration, material:int, smooth:int, start=null, end=null).(VoxelData.CALC_STATE.VOXEL, voxel_data, voxel_configuration): 
	self.metadata.name = "VoxelOpFill"
	self.new_material=material
	self.new_smooth=smooth
	self.start=start
	self.end = end


func to_string ():
	return "[VoxelOpFill]"


# Runs in main node to prepare data
func prepare():
	mat_buffer = voxel_data.material#.duplicate()
	smooth_buffer = voxel_data.smooth#.duplicate()


# This code is executed in another thread so it can not access voxel_node variable!
func execute(thread_cache : Dictionary):
	#print("!!! VoxelOpFill executing!")
	match voxel_configuration.accel_mode:
		VoxelConfiguration.ACCEL_MODE.NONE:
			fill()
		VoxelConfiguration.ACCEL_MODE.NATIVE:
			fill_native()


# This code will be executed in the main thread so access to voxel_node is ok
func finalize():
	if !mat_buffer or !smooth_buffer:
		push_error("mat_buffer or smooth_buffer missing!")
	voxel_data.material = mat_buffer
	voxel_data.smooth = smooth_buffer


# This code is executed in another thread so it can not access voxel_node variable!
func fill():
	#print("Filling...")
	
	var sx :int = voxel_data.voxel_count.x
	var sy :int = voxel_data.voxel_count.y
	var sz :int = voxel_data.voxel_count.z
	
	
	if start != null and end != null:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					if x >= start.x and x < end.x and y >= start.y and y < end.y and z >= start.z and z < end.z:
						mat_buffer[x + y*sx + z*sx*sy] = new_material
						if new_smooth != null:
							smooth_buffer[x + y*sx + z*sx*sy] = new_smooth
	else:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					mat_buffer[x + y*sx + z*sx*sy] = new_material
					if new_smooth != null:
						smooth_buffer[x + y*sx + z*sx*sy] = new_smooth

func fill_native():
	var native_worker = VoxelHammer.native_worker
	if not native_worker:
		push_error("VoxelOpVisibility: No native worker found. Falling back to ACCEL_MODE.NONE")
		fill()
		return
	
	if !start:
		start = Vector3(0,0,0)
	if !end:
		end = voxel_data.voxel_count
	
	var retarray = native_worker.create_fill(voxel_data.voxel_count, start, end, new_material, new_smooth, mat_buffer, smooth_buffer)
	
	mat_buffer = retarray[0]
	smooth_buffer = retarray[1]
