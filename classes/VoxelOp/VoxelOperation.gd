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

func run_operation():
	pass

func to_string():
	return name
