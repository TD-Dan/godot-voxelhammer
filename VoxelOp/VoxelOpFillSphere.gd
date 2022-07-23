extends VoxelOpFill

class_name VoxelOpFillSphere

var center = Vector3(0,0,0)
var radius = 0

func _init(voxel_data, voxel_configuration, material,smooth,center,radius,start=null,end=null).(voxel_data, voxel_configuration, material,smooth,start,end):
	self.metadata.name = "VoxelOpFillSphere"
	self.center = Vector3(center.x-0.5,center.y-0.5,center.z-0.5)
	self.radius = radius

func to_string ():
	return "[VoxelOpFillSphere]"
	
func fill():
	#print("Filling Sphere...")
	
	var sx :int = voxel_data.voxel_count.x
	var sy :int = voxel_data.voxel_count.y
	var sz :int = voxel_data.voxel_count.z
	
	if start != null and end != null:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					if x >= start.x and x < end.x and y >= start.y and y < end.y and z >= start.z and z < end.z:
						if (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)+(z-center.z)*(z-center.z) < radius*radius:
							mat_buffer[x + y*sx + z*sx*sy] = new_material
							if new_smooth != null:
								smooth_buffer[x + y*sx + z*sx*sy] = new_smooth
	else:
		for z in range(sz):
			for y in range(sy):
				for x in range(sx):
					if (x-center.x)*(x-center.x)+(y-center.y)*(y-center.y)+(z-center.z)*(z-center.z) < radius*radius:
						mat_buffer[x + y*sx + z*sx*sy] = new_material
						if new_smooth != null:
							smooth_buffer[x + y*sx + z*sx*sy] = new_smooth
