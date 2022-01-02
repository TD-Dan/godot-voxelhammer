extends TaskServerWorkItem

class_name VoxelOperation

var voxel_data

var calculation_level = 0

var voxel_configuration

func _init(calculation_level, voxel_data, voxel_configuration):
	self.metadata.name = "VoxelOp"
	self.calculation_level = calculation_level
	self.voxel_data = voxel_data
	self.voxel_configuration = voxel_configuration


func to_string ():
	return "[VoxelOperation]"
