@tool

extends Resource

class_name VoxelPaintStack

## Stack of Voxel paint operations
##
## Used for parametric generation of voxel geometry such as terrains and coloration patterns
##


signal operation_stack_changed

## Use global coordinates instead of local ones when calculating PaintOperations
@export var use_global_coordinates = true:
	set(nv):
		use_global_coordinates = nv
		operation_stack_changed.emit()


## Clear voxel_data to 0 before applying PaintStack
@export var clear_voxel_data = true:
	set(nv):
		clear_voxel_data = nv
		operation_stack_changed.emit()


## Clear blend_buffer to 0 before applying PaintStack
@export var clear_blend_buffer = false:
	set(nv):
		clear_blend_buffer = nv
		operation_stack_changed.emit()


## Array of PaintOperations
@export var operation_stack : Array = Array():
	set(nv):
		operation_stack = nv
		operation_stack_changed.emit()


@export_group("Helpers")
@export var notify_stack_changed : bool = false:
	set(nv):
		operation_stack_changed.emit()


enum AXIS_PLANE {
	X,
	Y,
	Z
}

enum PAINT_MODE {
	NORMAL,     # set voxel to material
	REPLACE,    # set voxel only if material already present
	ADD,        # set voxel only if no material present
	ERASE,      # set voxel to zero if material present
	NONE,       # dont draw material, only apply blend
}

enum BLEND_MODE {
	NORMAL,    # set blend value
	ADD,       # add to existing blend value
	MINUS,     # negate from existing blend value
	ONE_MINUS, # negate from 1
	MULTIPLY,  # multiply with existing blend value
	NONE,      # dont affect blend value
}


func add_paint_operation(paint_op):
	# TODO: Parser error: enable this or get @export var operation_stack : Array[PaintOperation] at line 17 to work
	# -> Wait for Godot 4.0 Beta to check if fixed
	#if paint_op is PaintOperation:
	#	error("paint_op needs to be subclass of PaintOperation")
	operation_stack.append(paint_op)
	operation_stack_changed.emit()

func remove_paint_operation(paint_op):
	operation_stack.erase(paint_op)
	operation_stack_changed.emit()

func move_paint_operation(paint_op, new_indx):
	if new_indx >= operation_stack.size():
		new_indx = operation_stack.size()-1
		push_warning("VoxelPaintStack: Trying to move paint_op beyond operation stack size")
	if new_indx < 0:
		new_indx = 0
		push_warning("VoxelPaintStack: Trying to move paint_op before operation stack start")
	
	var cur_pos = operation_stack.find(paint_op)
	
	print("VoxelPaintStack: Moving from %s to %s" % [cur_pos, new_indx])
	
	#if new_indx > cur_pos:
	#	new_indx -= 1
	operation_stack.erase(paint_op)
	operation_stack.insert(new_indx, paint_op)
	
	operation_stack_changed.emit()


func get_op_count():
	return operation_stack.size()
	
func _init():
	operation_stack = Array()
