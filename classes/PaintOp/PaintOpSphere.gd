@tool

extends PaintOperation

class_name PaintOpSphere

@export var center = Vector3(0,0,0)
@export var radius = 10.0

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, center = Vector3(0,0,0), radius = 10.0):
	super(blend_mode,material)
	self.center = center
	self.radius = radius
