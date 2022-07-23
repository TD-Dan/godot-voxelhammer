tool

extends StaticBody

class_name VoxelTerrainChunk


var voxel_size : int setget _set_voxel_size
var chunk_size : Vector3  setget _set_chunk_size

var col_shape : CollisionShape

var voxel_body : VoxelNode = VoxelNode.new()

export var do_terrain = false setget _set_do_terrain
export var do_test_fill = false setget _set_do_test_fill

# used by Terrain for fast indexed lookups
var index_x : int
var index_y : int
var index_z : int

func _set_voxel_size(nv):
	voxel_size = nv


func _set_chunk_size(nv):
	chunk_size = nv


func _set_do_terrain(nv):
	if nv:
		calculate_terrain()
	do_terrain = false


func _set_do_test_fill(nv):
	do_test_fill = nv
	calculate_terrain()


func _init(voxel_size = 1, chunk_size = Vector3(16,16,16)):
	self.voxel_size = voxel_size
	self.chunk_size = chunk_size


func _ready():
	#print("VoxelTerrainChunk ready ...")
	if not voxel_body:
		voxel_body = VoxelNode.new()
	
	add_child(voxel_body)
		
	voxel_body.voxel_data.voxel_count = chunk_size
	voxel_body.voxel_paint_local = false
		
	voxel_body.voxel_data.connect("voxel_data_changed", self, "_on_voxel_data_changed")
	
	if do_test_fill:
		_set_do_test_fill(do_test_fill)
	
	#print("VoxelTerrainChunk ready.")


func _process(delta):
	if do_terrain:
		calculate_terrain()
		do_terrain = false


func calculate_terrain():
	if !voxel_body:
		return
	
	if do_test_fill:
		voxel_body.do_fill = true
		return


func _on_voxel_data_changed(what):
	#print("VoxelThing: got signal voxel_data_changed %s" % what)
	if what >= VoxelData.CALC_STATE.MESH:
		create_collision_shape()


func create_collision_shape():
	#print("VoxelTerrainChunk: Creating collision shape for real_size: %s" % voxel_body.voxel_data.real_size)
	if not col_shape:
		col_shape = CollisionShape.new()
		add_child(col_shape)
	
	# TODO: temp solution, use mesh from VoxelNode
	col_shape.translation = voxel_body.voxel_data.real_size/2
	col_shape.shape = BoxShape.new()
	col_shape.shape.extents = voxel_body.voxel_data.real_size/2
	
