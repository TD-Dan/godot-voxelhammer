@tool

extends Node3D

class_name VoxelInstance3D

#
## VoxelData instance inside SceneTree
#
# Uses settings from VoxelConfiguration to generate and display a Mesh out of VoxelData
#

# Emitted when data is modified
signal data_changed(what)
# emitted when compilation of mesh (+ uv + normals and all) is complete
signal mesh_ready

@export var configuration : Resource:#VoxelConfiguration:
	set(nv):
		#print("set configuration to %s" % new_value)
		
		# Disconnect from previous configuration
		if configuration:
			if configuration.is_connected("voxel_configuration_changed", _on_voxel_configuration_changed):
				configuration.disconnect("voxel_configuration_changed", _on_voxel_configuration_changed)
		
		configuration = nv
		
		# Connect to new configuration
		if configuration:
			if not configuration.is_connected("voxel_configuration_changed", _on_voxel_configuration_changed):
				configuration.connect("voxel_configuration_changed", _on_voxel_configuration_changed)
		
		# TODO: force redraw of mesh

@export var voxel_data : Resource = VoxelData.new(): # : VoxelData
	set(nv):
		#print("_set_voxel_data")
		
		# Disconnect from previous voxel_data
		if voxel_data:
			if voxel_data.is_connected("voxel_data_changed", _on_voxels_changed):
				voxel_data.disconnect("voxel_data_changed", _on_voxels_changed)
		
		voxel_data = nv
		
		# Connect to new voxel_data
		if voxel_data:
			if not voxel_data.is_connected("voxel_data_changed", _on_voxels_changed):
				voxel_data.connect("voxel_data_changed", _on_voxels_changed)
				print("VoxelInstance3D %s: connect %s" % [self,voxel_data])

@export var paint_stack : Resource  = null: #VoxelPaintStack
	set(nv):
		paint_stack = nv
		if paint_stack:
			if voxel_data:
				voxel_data.clear()


var vis_buffer = null
var visibility_count = null

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
var current_operation : VoxelOperation = null
var ready_operations = []


func _ready():
	#print("VoxelNode: _ready")
	
	# Connect to VoxelHammer autoload
	var vh = get_node_or_null("/root/VoxelHammer")
	if vh:
		_debug_mesh_visible = vh.show_debug_gizmos
		vh.connect("show_debug_gizmos_changed", _on_show_debug_gizmos_changed)
			
		if not configuration:
			configuration = vh.default_configuration
	
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
	#print("VoxelInstance3D %s: _exit_tree" % self)
	
	if current_operation:
		current_operation.cancel = true
	for op in ready_operations:
		op.cancel = true
	for op in pending_operations:
		op.cancel = true


func _to_string():
	return "[VoxelInstance3D:%s]" % get_instance_id()


var my_self_bug_check_hack
func push_voxel_operation(vox_op : VoxelOperation):
	#print("VoxelInstance3D %s: push_voxel_operation %s" % [self,vox_op])
	my_self_bug_check_hack = self
	call_deferred("_deferred_push_voxel_op", vox_op)
	#_deferred_push_voxel_op(vox_op)

func _deferred_push_voxel_op(vox_op : VoxelOperation):
	# Remove all higher state calculations from pending operations, as they are now made invalid
	if current_operation and current_operation.calculation_level > vox_op.calculation_level:
		print("removing higher current op: %s" % str(current_operation))
		current_operation.cancel = true
		current_operation = null
	for op in pending_operations:
		if op.calculation_level > vox_op.calculation_level:
			print("removing higher op: %s" % str(op))
			op.cancel = true
			pending_operations.erase(op)
	
	vox_op.voxel_instance = self
	
	pending_operations.push_back(vox_op)
	
	_advance_operation_stack()

func _advance_operation_stack():
	#print("VoxelInstance3D %s: advance_operation_stack, stack: %s" % [self,str(pending_operations)])
	if not current_operation:
		#print("popping from stack %s" % str(current_operation))
		current_operation = pending_operations.pop_front()
		if current_operation:
			print("VoxelInstance3D %s: pop&run operation %s (pending_stack: %s)" % [self,current_operation, str(pending_operations)])
			match configuration.thread_mode:
				VoxelConfiguration.THREAD_MODE.NONE:
					current_operation.run_operation()
					current_operation = null
				VoxelConfiguration.THREAD_MODE.SIMPLE:
					pass
				VoxelConfiguration.THREAD_MODE.TASKSERVER:
					pass
					# TODO use TaskServer if available
		else:
			print("no current op")
	

func on_work_is_ready(work_item):
	#print("!!! VoxelNode got work item %s back!" % work_item.ticket)
	
	pending_operations.erase(work_item)
	ready_operations.push_back(work_item)


func _update_debug_mesh():
	#print("Creating debug mesh...")
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
	print("VoxelNode: _on_voxel_configuration_changed %s" % what)

	# Force recalculation of mesh
	_on_voxels_changed()

func _on_voxels_changed():
	if not my_self_bug_check_hack:
		# TODO: check if this Godot bug in signal emitting has been fixed
		print("%s: BUG_HACK: I'm not real! -> ingnoring." % self)
		return
	
	#print("VoxelInstance3D %s %s: _on_voxels_changed [0]=%s" % [self,my_self_bug_check_hack,str(voxel_data.data[0])])
	
	_debug_mesh_color = Color(0.5,0,0)

	emit_signal("data_changed", "voxels")

	# recalculate Mesh if no other vox operations pending
	if not current_operation and pending_operations.is_empty():
		call_deferred("push_voxel_operation",VoxelOpVisibility.new())

func notify_visibility_calculated():
	print("%s: visibility calculated: %s visible voxels" % [self,str(visibility_count)])
	
	_debug_mesh_color = Color(1,0.5,0)
	
	emit_signal("data_changed", "vis_buffer")