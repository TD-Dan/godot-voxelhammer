@tool

extends Node

class_name Octree

signal branch_added(OctreeBranch)

var roots : Dictionary # as Vector3i:Octet

var cache_size = 4:
	set(nv):
		cache_size = nv
		branch_cache.resize(cache_size)
var branch_cache : Array

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
	var level : int
	var user_data
	
	func get_branch(position : Vector3i, max_depth = -1, create_missing = true, callback_on_create = null) -> OctreeBranch:
		if self.size == 1 or self.level == max_depth: return self
		
		if children == null and create_missing:
			children = Array()
			children.resize(8)
		
		if children != null:
			var child_position = (position - self.position)/(size/2)
			var child_index = child_position.x+2*child_position.y+4*child_position.z
			#print(child_index)
			var found_child = children[child_index]
			if not found_child and create_missing:
				found_child = OctreeBranch.new()
				
				found_child.position = self.position + child_position * (size/2)
				found_child.size = size/2
				found_child.level = self.level - 1
				
				children[child_index] = found_child
				
				if callback_on_create != null:
					callback_on_create.call(found_child)
			
			if found_child:
				return found_child.get_branch(position, max_depth, create_missing, callback_on_create)
		
		return self

func _init():
	branch_cache.resize(cache_size)

var cache_rotating_index = 0
func get_branch(position : Vector3i, max_depth = -1, create_missing = true) -> OctreeBranch:
	if cache_size > 0:
		for cached_branch in branch_cache:
			if cached_branch and cached_branch.position == position:
				return cached_branch
	
	var root_position = position - Vector3i(max_size/2,max_size/2,max_size/2)
	root_position = root_position.snapped(Vector3i(max_size,max_size,max_size))
	var found_root = roots.get(root_position)
	if not found_root and create_missing:
		found_root = OctreeBranch.new()
		
		found_root.position = root_position
		found_root.size = max_size
		found_root.level = levels
		
		roots[root_position] = found_root
		_on_create_branch(found_root)
	
	if found_root:
		var found_branch = found_root.get_branch(position, max_depth, create_missing, _on_create_branch)
		if found_branch:
			if cache_size > 0:
				if cache_rotating_index >= cache_size:
					cache_rotating_index = 0
				branch_cache[cache_rotating_index] = found_branch
				cache_rotating_index +=1
			
			return found_branch
		
		return found_root
	
	return null


func clear():
	roots.clear()


func _on_create_branch(branch : OctreeBranch):
	emit_signal("branch_added", branch)
