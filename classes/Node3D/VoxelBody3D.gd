@tool

extends StaticBody3D

class_name VoxelBody3D

@export var paint_mode : bool = false
@export var paint_mat : int = 2

var voxel_instance : VoxelInstance

# Called when the node enters the scene tree for the first time.
func _ready():	
	connect("input_event", _on_input_event)
	
	call_deferred("_post_ready_deferred")


func _post_ready_deferred():
	voxel_instance = get_node_or_null("VoxelInstance")
	
	if not voxel_instance:
		print("creating new")
		voxel_instance = VoxelInstance.new()
		voxel_instance.name = "VoxelInstance"
		voxel_instance.voxel_data = load(VoxelHammer.plugin_directory + "res/vox_Letter_B_on_block.tres").duplicate()
		voxel_instance.generate_collision_sibling = VoxelInstance.COLLISION_MODE.CONCAVE_MESH
		add_child(voxel_instance)
	
	if Engine.is_editor_hint():
		voxel_instance.owner = get_tree().edited_scene_root


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.is_pressed():
		if paint_mode:
			#print("%s: got %s %s %s" % [self, str(event), str(position), str(normal)])
			var pos : Vector3 = to_local(position)
			var norm = (transform.basis * normal).normalized()
			var mat = -1
			
			#print("Localised position pre adjustment: " + str(pos) + ", normal:" + str(norm))
			
			if event.button_index == 1:
				pos = (pos + norm/2).floor()
				mat = paint_mat
			elif event.button_index == 3:
				pos = (pos - norm/2).floor()
				mat = 0
			
			#print("Localised position: " + str(pos) + ", normal:" + str(norm))
			
			if mat >= 0:
				#print("setting")
				voxel_instance.set_voxel(pos, mat)

