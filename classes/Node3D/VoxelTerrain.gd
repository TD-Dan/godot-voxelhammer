@tool

extends Node3D

class_name VoxelTerrain


@export var configuration : Resource  = null
@export var paint_stack : Resource  = null

@export var enable_collisions : bool = false:
	set(nv):
		enable_collisions = nv
		if is_inside_tree():
			push_warning("%s: Changing enable_collisions only takes effect when loading a scene.")

var chunk_space : ChunkSpace3D

## Chunk3D : VoxelInstance
var voxel_chunks : Dictionary


var _total_voxels : int = 0
## Total count of voxels loaded
func get_total_voxels():
		return _total_voxels


# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect to VoxelHammer autoload
	var vh = get_node_or_null("/root/VoxelHammer")
	if vh:
		if not configuration:
			configuration = vh.default_configuration
	
	chunk_space = get_node_or_null("ChunkSpace3D")
	if not chunk_space:
		chunk_space = ChunkSpace3D.new()
		chunk_space.name = "ChunkSpace3D"
		add_child(chunk_space)
	
	if Engine.is_editor_hint():
		chunk_space.owner = get_tree().edited_scene_root
	
	chunk_space.chunk_added.connect(_on_chunk_added)
	chunk_space.chunk_removed.connect(_on_chunk_removed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_chunk_added(chunk : Chunk3D):
	#print("chunk added")
	var new_vi = VoxelInstance.new()
	new_vi.configuration = configuration
	
	new_vi.voxel_data = VoxelData.new()
	new_vi.voxel_data.size = chunk_space.chunk_size
	
	new_vi.paint_stack = paint_stack
	
	var add_to_chunk = new_vi
	
	if enable_collisions:
		var new_body = StaticBody3D.new()
		new_vi.generate_collision_sibling = VoxelInstance.COLLISION_MODE.CONCAVE_MESH
		new_body.add_child(new_vi)
		add_to_chunk = new_body
	
	voxel_chunks[chunk] = add_to_chunk
	chunk.add_child(add_to_chunk)
	
	var num_voxels_added = new_vi.voxel_data.get_voxel_count()
	chunk.set_meta("___total_voxels", num_voxels_added)
	_total_voxels += num_voxels_added


func _on_chunk_removed(chunk : Chunk3D):
	#print("chunk removed")
	if voxel_chunks.erase(chunk):
		var num_voxels = chunk.get_meta("___total_voxels")
		_total_voxels -= num_voxels
	else:
		push_warning("%s: Trying to remove %s: Does not exist in VoxelTerrain! (not added in the first place?)" % [self, chunk])


func _to_string():
	var idstr : String = str(get_instance_id())
	return "[VoxelTerrain%s]" % idstr.substr(idstr.length()-4)
