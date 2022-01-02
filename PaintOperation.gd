tool

extends Resource

class_name PaintOperation

# Abstract base class for paint operations

export(VoxelPaintStack.PAINT_MODE) var paint_mode = VoxelPaintStack.PAINT_MODE.NORMAL
export(VoxelPaintStack.BLEND_MODE) var blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL
export(float, -10.0, 10.0, 0.01) var blend_amount = 1
export(int, 1024) var material = 1
export var smooth = false
export var active = true


func _init(blend_mode = VoxelPaintStack.PAINT_MODE.NORMAL, material = 1, smooth = false):
	self.paint_mode = paint_mode
	self.material = material
	self.smooth = smooth
