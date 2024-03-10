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
# Called in main thread before executing 'run_operation'
func prepare_run_operation():
	return


# Virtual
# This code is potentially executed in another thread!
func run_operation():
	call_deferred("push_error", "'run_operation()' not implemented!")


func _to_string():
	var id : String = str(get_instance_id())
	return "[%s..%s]" % [name,id.substr(id.length()-4)]
	
	
