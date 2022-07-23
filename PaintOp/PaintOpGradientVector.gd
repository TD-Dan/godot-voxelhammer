tool

extends PaintOperation

class_name PaintOpGradientVector

export var offset = 0
export var distance = 10
export var mirror = false
export var plane = Vector3(0,1,0)

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, smooth = false, offset = 0, distance = 10).(blend_mode,material,smooth):
	self.offset = offset
	self.distance = distance
