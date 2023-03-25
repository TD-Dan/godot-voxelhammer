@tool

extends VoxelOperation

class_name VoxelOpSphere

var new_value : int
var start #: null or Vector3i
var end #: null or Vector3i
var center : Vector3
var radius : float
var clear : bool

# Radius and center are given as voxels and are calculated in local voxel space
func _init(fill_value:int, center : Vector3, radius : float, clear=false, start=null, end=null):
	super("VoxelOpSphere", VoxelOperation.CALCULATION_LEVEL.VOXEL+10)
	new_value = fill_value
	self.start = start
	self.end = end
	self.center = Vector3(center.x-0.5,center.y-0.5,center.z-0.5)
	self.radius = radius
	self.clear = clear

# This code is potentially executed in another thread!
func run_operation():
	#print("%s: run_operation on %s" % [self,voxel_instance])
	if voxel_instance.voxel_data.data_mutex.try_lock():
		fillsphere(voxel_instance.voxel_data.data, voxel_instance.voxel_data.size, new_value, start, end)
		voxel_instance.voxel_data.data_mutex.unlock()
		voxel_instance.voxel_data.call_deferred("notify_data_changed")
	else:
		call_deferred("push_warning", "VoxelOpFill: Can't get lock on voxel data!")

# This code is potentially executed in another thread!
func fillsphere(data : PackedInt64Array, size : Vector3i, value : int, start = null, end = null):
	#print("Filling with %s ..." % value)
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	if start != null and end != null:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					if x >= start.x and x < end.x and y >= start.y and y < end.y and z >= start.z and z < end.z:
						if (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)+(z-center.z)*(z-center.z) < radius*radius:
							data[x + y*sx + z*sx*sy] = value
						elif clear:
							data[x + y*sx + z*sx*sy] = 0
	else:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					if (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)+(z-center.z)*(z-center.z) < radius*radius:
						data[x + y*sx + z*sx*sy] = value
					elif clear:
						data[x + y*sx + z*sx*sy] = 0
