@tool

extends Node3D

class_name OctreeNode

var size : int = 1
var sub_nodes : Array[OctreeNode] = []
var leaf_mesh : Node3D

var type = OCTREE_TYPE.TRUNK

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

enum OCTREE_TYPE {
	ROOT,
	TRUNK,
	BRANCH,
	LEAF
}

# Called when the node enters the scene tree for the first time.
func _ready():
	_debug_mesh = DebugMesh.new()
	add_child.call_deferred(_debug_mesh)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func refresh_position(target_pos : Vector3):
	if not is_inside_tree():
		return
	
	_debug_mesh.size = Vector3(size,size,size)
	
	_debug_mesh.mesh_color.g = 0
	if size == 1:
		type = OCTREE_TYPE.LEAF
		_debug_mesh.mesh_color.g = 1
		return
	
	var gpos = global_position
	
	
	match type:
		OCTREE_TYPE.ROOT: _debug_mesh.mesh_color.r = 1
		OCTREE_TYPE.TRUNK: _debug_mesh.mesh_color.r = 0.75
		OCTREE_TYPE.BRANCH:
			_debug_mesh.mesh_color.r = 0.25
			_debug_mesh.mesh_color.g = 0.5
		OCTREE_TYPE.LEAF:
			_debug_mesh.mesh_color.r = 0
	
	_debug_mesh.mesh_color.b = 0
	
	var is_inside = false
	
	if target_pos.x - size/2 < gpos.x + size and target_pos.x + size/2 > gpos.x - size and \
		target_pos.y - size/2 < gpos.y + size and target_pos.y + size/2 > gpos.y - size and \
		target_pos.z - size/2 < gpos.z + size and target_pos.z + size/2 > gpos.z - size:
			is_inside = true
	
	if is_inside:
		_debug_mesh.mesh_color.b = 1
		
		if size > 1:
			if sub_nodes.is_empty():
				for i in range(8):
					var new_sub_node = OctreeNode.new()
					new_sub_node.type = OCTREE_TYPE.TRUNK
					new_sub_node.size = size / 2
					new_sub_node.position = octree_initial_positions[i] * size / 2
					sub_nodes.append(new_sub_node)
					add_child.call_deferred(new_sub_node)
			
			for sub in sub_nodes:
				sub.refresh_position(target_pos)
	else:
		type = OCTREE_TYPE.BRANCH
		for sub in sub_nodes:
			sub.queue_free()
		sub_nodes = []
