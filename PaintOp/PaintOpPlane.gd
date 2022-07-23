tool

extends PaintOperation

class_name PaintOpPlane

export var low = -10
export var high = 10
export(VoxelPaintStack.AXIS_PLANE) var plane = VoxelPaintStack.AXIS_PLANE.Y

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, smooth = false, low = 0, high = 1).(blend_mode,material,smooth):
	self.low = low
	self.high = high
