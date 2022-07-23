@tool

extends Resource

class_name VoxelPaintStack

#
## Stack of Voxel paint operations
#
# Used for parametric generation of voxel geometry such as terrains and coloration patterns
#


signal operation_stack_changed

# Array of PaintOperations
@export var operation_stack : Array = Array():
	set(v):
		operation_stack = v
		emit_signal("operation_stack_changed")

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

func remove_paint_operation(paint_op):
	operation_stack.erase(paint_op)

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


func get_op_count():
	return operation_stack.size()
	
func _init():
	operation_stack = Array()
