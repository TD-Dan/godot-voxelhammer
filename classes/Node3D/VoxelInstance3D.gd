@tool

extends Node3D

class_name VoxelInstance3D

#
## VoxelData instance inside SceneTree
#
# Uses settings from VoxelConfiguration to generate and display a Mesh out of VoxelData
#

# emitted when compilation of mesh (+ uv + normals and all) is complete
signal mesh_ready

@export var configuration : Resource:#VoxelConfiguration:
	set(nv):
		#print("set configuration to %s" % new_value)
		if configuration:
			if configuration.is_connected("voxel_configuration_changed", _on_voxel_configuration_changed):
				configuration.disconnect("voxel_configuration_changed", _on_voxel_configuration_changed)
		
		configuration = nv
		
		if configuration:
			if not configuration.is_connected("voxel_configuration_changed", _on_voxel_configuration_changed):
				configuration.connect("voxel_configuration_changed", _on_voxel_configuration_changed)
		
		# force redraw of mesh
		if voxel_data and voxel_data.calculation_state > VoxelData.CALC_STATE.MESH:
			voxel_data.set_state(VoxelData.CALC_STATE.MESH-1)

@export var voxel_data : Resource = VoxelData.new(): # : VoxelData
	set(nv):
		#print("_set_voxel_data")
		if voxel_data:
			if voxel_data.is_connected("voxels_changed", _on_voxels_changed):
				voxel_data.disconnect("voxels_changed", _on_voxels_changed)
		
		voxel_data = nv
		
		if voxel_data:
			if not voxel_data.is_connected("voxels_changed", _on_voxels_changed):
				voxel_data.connect("voxels_changed", _on_voxels_changed)

@export var paint_stack : Resource  = null: #VoxelPaintStack
	set(nv):
		paint_stack = nv
		if paint_stack:
			if voxel_data:
				voxel_data.clear()


var mesh_child


# Debug linemesh that shows current mesh calculation status and size
var _debug_mesh_child : MeshInstance3D = null
var _debug_mesh_visible = false:
	set(v):
		_debug_mesh_visible = v
		if _debug_mesh_visible:
			_update_debug_mesh()
		else:
			if _debug_mesh_child:
				_debug_mesh_child.mesh = null
var _debug_mesh_color : Color = Color(0,0,0):
	set(v):
		_debug_mesh_color = v
		#print("set debug mesh color to %s" % debug_mesh_color)
		if _debug_mesh_visible:
			_update_debug_mesh()



var pending_operations = []
var current_operation = null
var ready_operations = []

var mesh_is_ready = false


func _init():
	#print("VoxelNode init")
	if not configuration:
		configuration = VoxelHammer.default_configuration


func _ready():	
	#print("VoxelNode: _ready")
	_debug_mesh_visible = VoxelHammer.show_debug_gizmos
	VoxelHammer.connect("show_debug_gizmos_changed", _on_show_debug_gizmos_changed)
	
	# TODO: If TaskServer plugin is present connect to it
	var th_autoload_global = get_node_or_null("/root/TaskHammer")
	if th_autoload_global:
		print("Found TaskHammer plugin! Integrating...")
	else:
		push_warning("(OPTIONAL) TaskHammer Global Autoload NOT found. TaskHammer plugin installed? Falling back to single thread execution..")
	
	mesh_child = MeshInstance3D.new()
	add_child(mesh_child)
	
	#print("VoxelNode: _ready is done")


func _exit_tree():
	#print("cancel pending work items")
	if current_operation:
		current_operation.cancel = true
	for op in ready_operations:
		op.cancel = true
	for op in pending_operations:
		op.cancel = true




func push_voxel_operation(vox_op : VoxelOperation):
	call_deferred("_deferred_push_voxel_op", vox_op)

func _deferred_push_voxel_op(vox_op : VoxelOperation):
	#print("Add voxel op: %s" % vox_op.to_string())
	
	# Remove all higher state calculations from pending operations, as they are now made invalid
	for op in pending_operations:
		if op.calculation_level >= vox_op.calculation_level:
			op.cancel = true
			pending_operations.erase(op)
	
	pending_operations.push_back(vox_op)


func on_work_is_ready(work_item):
	#print("!!! VoxelNode got work item %s back!" % work_item.ticket)
	
	pending_operations.erase(work_item)
	ready_operations.push_back(work_item)


func _update_debug_mesh():
	print("Creating debug mesh...")
	if not _debug_mesh_child:
		_debug_mesh_child = MeshInstance3D.new()
		add_child(_debug_mesh_child)
	
	var size = voxel_data.size * configuration.voxel_base_size
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(_debug_mesh_color)
	
	st.add_vertex(Vector3(0,0,0))
	st.add_vertex(Vector3(size.x,0,0))
	st.add_vertex(Vector3(0,size.y,0))
	st.add_vertex(Vector3(size.x,size.y,0))
	st.add_vertex(Vector3(0,size.y,size.z))
	st.add_vertex(Vector3(size.x,size.y,size.z))
	st.add_vertex(Vector3(0,0,size.z))
	st.add_vertex(Vector3(size.x,0,size.z))
	
	st.add_vertex(Vector3(0,0,0))
	st.add_vertex(Vector3(0,size.y,0))
	st.add_vertex(Vector3(size.x,0,0))
	st.add_vertex(Vector3(size.x,size.y,0))
	st.add_vertex(Vector3(size.x,0,size.z))
	st.add_vertex(Vector3(size.x,size.y,size.z))
	st.add_vertex(Vector3(0,0,size.z))
	st.add_vertex(Vector3(0,size.y,size.z))
	
	st.add_vertex(Vector3(0,0,0))
	st.add_vertex(Vector3(0,0,size.z))
	st.add_vertex(Vector3(size.x,0,0))
	st.add_vertex(Vector3(size.x,0,size.z))
	st.add_vertex(Vector3(size.x,size.y,0))
	st.add_vertex(Vector3(size.x,size.y,size.z))
	st.add_vertex(Vector3(0,size.y,0))
	st.add_vertex(Vector3(0,size.y,size.z))
	
	_debug_mesh_child.mesh = st.commit()
	_debug_mesh_child.mesh.surface_set_material(0, load("res://addons/TallDwarf/VoxelHammer/res/line.tres"))


func _on_show_debug_gizmos_changed(value):
	#print("VoxelInstance3D: Changing debug mesh visibility to " + str(value))
	_debug_mesh_visible = value

func _on_voxel_configuration_changed(what):
	#print("VoxelNode: _on_voxel_configuration_changed %s" % what)

	# TODO:force recalculation of mesh
	pass

func _on_voxels_changed():
	#print("VoxelNode: _on_voxels_changed")
	
	if _debug_mesh_visible:
		_update_debug_mesh()
	
	# TODO: recalculate Mesh
