@tool

extends PaintOperation

class_name PaintOpNoise

@export var noise = FastNoiseLite.new()

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, smooth = false):
	super(blend_mode,material,smooth)
