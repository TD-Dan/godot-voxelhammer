extends Node3D


@onready var n1 : VoxelInstance3D = $N6
@onready var n2 : VoxelInstance3D = $N8
@onready var n3 : VoxelInstance3D = $N16
@onready var n4 : VoxelInstance3D = $N32
@onready var n5 : VoxelInstance3D = $N64

var voxel_sizes_total =[6*6*6, 8*8*8, 16*16*16, 32*32*32, 64*64*64]
var performance_mesh_update_counter = Array()
var performance_voxels = Array()

# Called when the node enters the scene tree for the first time.
func _ready():
	for item in VoxelConfiguration.MESH_MODE.keys():
		%OptionButtonMesh.add_item(item)
	
	for item in VoxelConfiguration.THREAD_MODE.keys():
		%OptionButtonThread.add_item(item)
	
	%OptionButtonMesh.selected = VoxelHammer.default_configuration.mesh_mode
	%OptionButtonThread.selected = VoxelHammer.default_configuration.thread_mode
	
	n1.connect("data_changed", _on_mesh_updated.bind(1))
	n2.connect("data_changed", _on_mesh_updated.bind(2))
	n3.connect("data_changed", _on_mesh_updated.bind(3))
	n4.connect("data_changed", _on_mesh_updated.bind(4))
	n5.connect("data_changed", _on_mesh_updated.bind(5))
	
	performance_mesh_update_counter.resize(5)
	performance_mesh_update_counter.fill(0)
	performance_voxels.resize(5)
	performance_voxels.fill(0)

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

func _on_mesh_updated(what,who):
	if what == "mesh":
		performance_mesh_update_counter[who-1] += 1


func _on_performance_timer_timeout():
	
	var voxels_total = 0
	var mesh_updates = ""
	var voxel_counts = ""
	for i in performance_mesh_update_counter.size():
		mesh_updates += "%s " % performance_mesh_update_counter[i]
		var voxel_count = performance_mesh_update_counter[i] * voxel_sizes_total[i]
		voxels_total += voxel_count
		voxel_counts += "%s " % voxel_count
		
	
	%PerformanceLabel.text = "Mesh updates per second: "
	%PerformanceLabel.text += mesh_updates
	%PerformanceLabel.text += "\nVoxels per second: "
	%PerformanceLabel.text += voxel_counts
	%PerformanceLabel.text += "\nTotal voxels per second: "
	%PerformanceLabel.text += str(voxels_total)
	
	performance_mesh_update_counter.fill(0)
	
