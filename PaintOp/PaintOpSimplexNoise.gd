tool

extends PaintOperation

class_name PaintOpSimplexNoise

export var lucanarity : float = 2.0 setget _set_lucanarity
export var octaves : int = 3 setget _set_octaves
export var period : float = 64.0 setget _set_period
export var persistence : float = 0.5 setget _set_persistence
export var rseed : int = 0 setget _set_rseed

var noise = OpenSimplexNoise.new()

func _init(blend_mode = VoxelPaintStack.BLEND_MODE.NORMAL, material = 1, smooth = false).(blend_mode,material,smooth):
	noise.lacunarity = lucanarity
	noise.octaves = octaves
	noise.period = period
	noise.persistence = persistence
	noise.seed = rseed

func _set_lucanarity(nv):
	lucanarity = nv
	noise.lacunarity = lucanarity

func _set_octaves(nv):
	octaves = nv
	noise.octaves = octaves

func _set_period(nv):
	period = nv
	noise.period = period

func _set_persistence(nv):
	persistence = nv
	noise.persistence = persistence

func _set_rseed(nv):
	rseed = nv
	noise.seed = rseed
