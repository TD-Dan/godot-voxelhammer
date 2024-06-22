@tool

extends VoxelOperation

class_name VoxelOpSphere

var new_value : int
var center : Vector3
var radius : float
var clear : bool

# Radius and center are given as voxels and are calculated in local voxel space
func _init(fill_value:int, center : Vector3, radius : float, clear=false):
	super("VoxelOpSphere", VoxelOperation.CALCULATION_LEVEL.VOXEL+10)
	new_value = fill_value
	self.center = Vector3(center.x-0.5,center.y-0.5,center.z-0.5)
	self.radius = radius
	self.clear = clear

# This code is potentially executed in another thread!
func run_operation():
	#print("%s: run_operation on %s" % [self,voxel_instance])
	var local_data_buffer
	var local_data_dimensions
	if clear:
		local_data_buffer = PackedInt64Array()
		voxel_instance.voxel_data.data_mutex.lock()
		local_data_buffer.resize(voxel_instance.voxel_data.get_voxel_count())
		local_data_dimensions = voxel_instance.voxel_data.size
		voxel_instance.voxel_data.data_mutex.unlock()
		local_data_buffer.fill(0)
	else:
		voxel_instance.voxel_data.data_mutex.lock()
		local_data_buffer = voxel_instance.voxel_data.data.duplicate()
		local_data_dimensions = voxel_instance.voxel_data.size
		voxel_instance.voxel_data.size
		voxel_instance.voxel_data.data_mutex.unlock()
	
	if cancel: return
	
	fillsphere(local_data_buffer, local_data_dimensions, new_value, center, radius)
	
	if cancel: return
	
	voxel_instance.voxel_data.data_mutex.lock()
	voxel_instance.voxel_data.data = local_data_buffer
	voxel_instance.voxel_data.data_mutex.unlock()
	
	
	voxel_instance.voxel_data.notify_data_changed.call_deferred()
	voxel_instance.notify_operation_is_ready.call_deferred()


# This code is potentially executed in another thread!
func fillsphere(data : PackedInt64Array, size : Vector3i, value : int, center : Vector3, radius : float):
	#print("Filling with %s ..." % value)
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	for z in range(sz):
		if cancel: return
		for y in range(sy):
			for x in range(sx):
				if (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)+(z-center.z)*(z-center.z) < radius*radius:
					data[x + y*sx + z*sx*sy] = value
