@tool

extends Node

class_name Octree

signal branch_added(OctreeBranch)

var roots : Dictionary # as Vector3i:Octet
var leaves : Array # as Octet for faster leaf lookups

@export var max_size : int = 16:
	set(nv):
		if nv+1 == max_size:	# This allows using spinner editing in inspector
			nv = max_size/2
		max_size = maxi(nearest_po2(nv),1)

@export var levels : int = 4:
	get:
		var count = 0
		var temp = max_size
		while temp > 1 and count < 54:
			temp /= 2
			count += 1
		return count

class OctreeBranch:
	var position : Vector3i
	var size : int
	var children
	var is_root : bool
	var level : int
	var user_data
	
	func get_branch(position : Vector3i, max_depth = -1, create_missing = true):
		if children == null:
			children = Array()
			children.resize(8)
		#var index_key = 

func get_branch(position : Vector3i, max_depth = -1, create_missing = true):
	var root_key = position.snapped(Vector3i(max_size,max_size,max_size))
	var found_root = roots.get(root_key)
	if not found_root and create_missing:
		found_root = OctreeBranch.new()
		found_root.is_root = true
		found_root.position = root_key
		found_root.size = max_size
		roots[root_key] = found_root
		emit_signal("branch_added", found_root)
	
	found_root.get_branch(position)
