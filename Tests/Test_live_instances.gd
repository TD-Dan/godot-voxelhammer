extends Node3D


@onready var n1 : VoxelInstance3D = $N6
@onready var n2 : VoxelInstance3D = $N8
@onready var n3 : VoxelInstance3D = $N16
@onready var n4 : VoxelInstance3D = $N32
@onready var n5 : VoxelInstance3D = $N64

# Called when the node enters the scene tree for the first time.
func _ready():
	for item in VoxelConfiguration.MESH_MODE.keys():
		%OptionButtonMesh.add_item(item)
	
	for item in VoxelConfiguration.THREAD_MODE.keys():
		%OptionButtonThread.add_item(item)
	
	%OptionButtonMesh.selected = VoxelHammer.default_configuration.mesh_mode
	%OptionButtonThread.selected = VoxelHammer.default_configuration.thread_mode


var elapsed = 0.0
var frame_limit = 1/120
var frame_limit_counter = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	elapsed += delta
	frame_limit_counter += delta
	if frame_limit_counter >= frame_limit:
		frame_limit_counter -= frame_limit
		var phase = (sin(elapsed/2.0)+1.0)/2.0
		#print(phase)
		n1.push_voxel_operation(VoxelOpSphere.new(2,Vector3(n1.voxel_data.size)/2.0+Vector3(0.1,0.2,0.3), n1.voxel_data.size.x/2*phase, true))
		
		n2.push_voxel_operation(VoxelOpSphere.new(2,Vector3(n2.voxel_data.size)/2.0+Vector3(0.1,0.2,0.3), n2.voxel_data.size.x/2*phase, true))
		
		n3.push_voxel_operation(VoxelOpSphere.new(2,Vector3(n3.voxel_data.size)/2.0+Vector3(0.1,0.2,0.3), n3.voxel_data.size.x/2*phase, true))
		
		n4.push_voxel_operation(VoxelOpSphere.new(2,Vector3(n4.voxel_data.size)/2.0+Vector3(0.1,0.2,0.3), n4.voxel_data.size.x/2*phase, true))
		
		n5.push_voxel_operation(VoxelOpSphere.new(2,Vector3(n5.voxel_data.size)/2.0+Vector3(0.1,0.2,0.3), n5.voxel_data.size.x/2*phase, true))


func _on_option_button_mesh_item_selected(index):
	VoxelHammer.default_configuration.mesh_mode = index


func _on_option_button_thread_item_selected(index):
	VoxelHammer.default_configuration.thread_mode = index
