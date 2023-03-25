@tool

extends RefCounted #inherit RefCounted for automatic memory management, more lightweight than Node

class_name VoxelOperation

#### KWAK! implements TaskServerWorkItem:
var cancel = false
var name = "VoxelOperation"
####


var voxel_instance : VoxelInstance3D

enum CALCULATION_LEVEL {
	NONE = 0,
	VOXEL = 100,
	PRE_MESH = 200,
	MESH = 300,
	POST_MESH = 400
}
var calculation_level = 0


func _init(name:String, calculation_level:CALCULATION_LEVEL):
	self.name = name
	self.calculation_level = calculation_level
	

# Virtual
func run_operation():
	call_deferred("push_error", "'run_operation()' not implemented!")

func _to_string():
	return "[%s:%s]" % [name,get_instance_id()]
