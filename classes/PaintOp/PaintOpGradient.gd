@tool

extends PaintOperation

class_name PaintOpGradient

@export var offset = 0
@export var distance = 10
@export var mirror = false
@export var reverse = false
@export var plane : VoxelPaintStack.AXIS_PLANE = VoxelPaintStack.AXIS_PLANE.Y

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, offset = 0, distance = 10):
	super(blend_mode,material)
	self.offset = offset
	self.distance = distance
