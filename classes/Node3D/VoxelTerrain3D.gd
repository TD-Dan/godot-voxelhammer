@tool

extends Node3D

class_name VoxelTerrain3D

var _chunk_size = 32
## Number of voxels in each axis per chunk. Chunks are always cubic.
@export var chunk_size = 32:
	set(nv):
		if nv < _chunk_size:
			_chunk_size /= 2
		else:
			_chunk_size *= 2
		_chunk_size = clamp(_chunk_size,1,pow(2,10))
	get:
		return _chunk_size

## Read only. Size of the smallest voxel in voxel units. Smallest detail in the terrain.
@export var smallest_voxel = 1.0:
	get:
		return float(_cascade_smallest_size) / _chunk_size

## Read only. Size of the largest voxel in voxel units. This is the size of voxels that are shown at the farthest from viewer.
@export var largest_voxel = 1.0:
	get:
		return _cascade_biggest_size / _chunk_size

@export_group("Octree divisions")
var _cascade_biggest_size = 4096
## Biggest chunk size to generate. Effectively the farthest that can be seen.
## In practise view horizon can be as close as half of this depending on player position on the octree.
@export var cascade_biggest_size = 4096:
	set(nv):
		if nv < _cascade_biggest_size:
			_cascade_biggest_size /= 2
		else:
			_cascade_biggest_size *= 2
		_cascade_biggest_size = clamp(_cascade_biggest_size,_cascade_smallest_size,pow(2,16))
		
		_calculate_num_cascades()
	get:
		return _cascade_biggest_size


var _cascade_smallest_size = 32
## Smallest chunk size to generate. This divided by chunk 
@export var cascade_smallest_size = 32:
	set(nv):
		if nv < _cascade_smallest_size:
			_cascade_smallest_size /= 2
		else:
			_cascade_smallest_size *= 2
		_cascade_smallest_size = clamp(_cascade_smallest_size,1,_cascade_biggest_size)
		
		_calculate_num_cascades()
	get:
		return _cascade_smallest_size


var _chunk_cascades = 8
## Number of progressively larger chunk sizes to generate
@export var chunk_cascades = 8:
	set(nv):
		_chunk_cascades = clamp(nv, 1, 32)
		_calculate_biggest_size()
	get:
		return _chunk_cascades

## Read only. 
@export var total_chunks = 8:
	get:
		return 8 * _chunk_cascades

func _calculate_biggest_size():
		_cascade_biggest_size = _cascade_smallest_size
		for n in _chunk_cascades-1:
			_cascade_biggest_size *= 2


func _calculate_num_cascades():
	var temp = _cascade_biggest_size
	var n = 1
	while temp != _cascade_smallest_size:
		temp /= 2
		n += 1
	_chunk_cascades = n


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
