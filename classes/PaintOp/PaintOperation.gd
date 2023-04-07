@tool

extends Resource

class_name PaintOperation

# Abstract base class for all paint operations

@export var paint_mode : VoxelPaintStack.PAINT_MODE = VoxelPaintStack.PAINT_MODE.NORMAL
@export var blend_mode : VoxelPaintStack.BLEND_MODE = VoxelPaintStack.BLEND_MODE.NORMAL
@export_range(0.0, 10.0, 0.01) var blend_amount : float = 1.0
@export_range(0, 1024, 1) var material : int = 1
@export var active = true


func _init(blend_mode = VoxelPaintStack.PAINT_MODE.NORMAL, material = 1):
	self.paint_mode = paint_mode
	self.material = material
