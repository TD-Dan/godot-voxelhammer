@tool

extends PaintOperation

class_name PaintOpSimplexNoise

@export var lucanarity : float = 2.0:
	set(nv):
		lucanarity = nv
		#noise.lacunarity = lucanarity
@export var octaves : int = 3:
	set(nv):
		octaves = nv
		#noise.octaves = octaves
@export var period : float = 64.0:
	set(nv):
		period = nv
		#noise.period = period
@export var persistence : float = 0.5:
	set(nv):
		persistence = nv
		#noise.persistence = persistence
@export var rseed : int = 0:
	set(nv):
		rseed = nv
		#noise.seed = rseed

# TODO: OpenSimplexNoise still in Godot 4.0, but not implemented or needs to be raplaced with FastNoiseLite ???
#var noise = OpenSimplexNoise.new()

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, smooth = false):
	super(blend_mode,material,smooth)
#	noise.lacunarity = lucanarity
#	noise.octaves = octaves
#	noise.period = period
#	noise.persistence = persistence
#	noise.seed = rseed




