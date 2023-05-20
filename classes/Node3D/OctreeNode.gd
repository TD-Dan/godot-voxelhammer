@tool

extends Node3D

class_name OctreeNode

var size : int = 1
var leaf_size : int = 1
var sub_nodes : Array[OctreeNode] = []

var configuration : VoxelConfiguration
var paint_stack : VoxelPaintStack

var leaf_mesh : VoxelInstance3D

var _debug_mesh : Node3D

var octree_initial_positions = [
	Vector3i(0,0,0),
	Vector3i(1,0,0),
	Vector3i(0,1,0),
	Vector3i(1,1,0),
	Vector3i(0,0,1),
	Vector3i(1,0,1),
	Vector3i(0,1,1),
	Vector3i(1,1,1),
]

# Called when the node enters the scene tree for the first time.
func _ready():
	_debug_mesh = DebugMesh.new()
	add_child.call_deferred(_debug_mesh)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


var iterator = -2

# return value indicates whether all children have been processed
func refresh_position(target_pos : Vector3) -> bool:
	if not is_inside_tree():
		return true
	
	# Run self refresh
	if iterator == -2:
		_debug_mesh.size = Vector3(size,size,size)
		
		# if already at smallest size, update it
		if size == leaf_size:
			if not leaf_mesh:
				_debug_mesh.mesh_color = Color(0.25,1,0.25)
				leaf_mesh = VoxelInstance3D.new()
				leaf_mesh.voxel_data = VoxelData.new()
				leaf_mesh.voxel_data.size = Vector3i(size,size,size)
				leaf_mesh.configuration = configuration
				leaf_mesh.paint_stack = paint_stack
				add_child.call_deferred(leaf_mesh)
			#else:
			#	leaf_mesh.apply_paintstack() # Not good will constantly repaint
			return true
		
		# Test if we need more detailed sub trees
		var is_inside = false
		var gpos = global_position
		if target_pos.x - size/2 < gpos.x + size and target_pos.x + size/2 > gpos.x - size and \
			target_pos.y - size/2 < gpos.y + size and target_pos.y + size/2 > gpos.y - size and \
			target_pos.z - size/2 < gpos.z + size and target_pos.z + size/2 > gpos.z - size:
				is_inside = true
		
		if is_inside:
			_debug_mesh.mesh_color.b = 1
		
			if size > leaf_size and sub_nodes.is_empty():
				for i in range(8):
					var new_sub_node = OctreeNode.new()
					new_sub_node.size = size / 2
					new_sub_node.leaf_size = leaf_size
					new_sub_node.position = octree_initial_positions[i] * size / 2
					new_sub_node.configuration = configuration
					new_sub_node.paint_stack = paint_stack
					sub_nodes.append(new_sub_node)
					add_child.call_deferred(new_sub_node)
		else:
			for sub in sub_nodes:
				sub.queue_free()
			sub_nodes = []
		
		iterator = -1
	
	if iterator == -1: iterator = sub_nodes.size()-1
	
	if iterator > -1:
		var sub = sub_nodes[iterator]
		if sub.refresh_position(target_pos):
			iterator -= 1
		if iterator > -1:
			# still processing children, message parent to keep halt iteration
			return false
		
		# All children have been processed, refresh self
		iterator = -2
		return true
	
	iterator = -2
	return true
