@tool

extends Node3D

class_name VoxelTerrain


@export var configuration : Resource  = null
@export var paint_stack : Resource  = null

var chunk_space : ChunkSpace3D

# Chunk3D : VoxelInstance
var voxel_chunks : Dictionary

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
	print("chunk added")
	var new_vi = VoxelInstance.new()
	new_vi.configuration = configuration
	new_vi.paint_stack = paint_stack
	chunk.add_child(new_vi)


func _on_chunk_removed(chunk : Chunk3D):
	print("chunk removed")
	pass
