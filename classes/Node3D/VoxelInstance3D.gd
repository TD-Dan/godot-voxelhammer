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
				#print("%s: connect %s" % [self,configuration])
		
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
				#print("%s: connect %s" % [self,voxel_data])

@export var paint_stack : Resource  = null: #VoxelPaintStack
	set(nv):
		paint_stack = nv
		if paint_stack:
			if voxel_data:
				voxel_data.clear()


var col_sibling

enum COLLISION_MODE{
	NONE,
	CUBE,
	CONVEX_MESH,
	CONCAVE_MESH
}
@export var generate_collision_sibling : COLLISION_MODE = COLLISION_MODE.NONE:
	set(nv):
		generate_collision_sibling = nv
		if not generate_collision_sibling and col_sibling:
			col_sibling.queue_free()
			col_sibling = null


var vis_buffer : PackedByteArray = PackedByteArray()
var visibility_count = null

@onready var mesh_child : MeshInstance3D  = $MeshInstance3D

var mesh_surfaces_count = null
var mesh_faces_count = null


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
		if configuration.thread_mode == VoxelConfiguration.THREAD_MODE.TASKSERVER:
			push_warning("(OPTIONAL) TaskServer Global Autoload NOT found. TaskServer plugin installed? Falling back to simple thread execution..")
			configuration.thread_mode = VoxelConfiguration.THREAD_MODE.SIMPLE
	
	# Calculate Visibility (and Mesh) 
	call_deferred("push_voxel_operation",VoxelOpVisibility.new())
	
	#print("VoxelNode: _ready is done")

func _enter_tree():
	if col_sibling:
		get_parent().add_child(col_sibling)

func _exit_tree():
	#print("VoxelInstance3D %s: _exit_tree" % self)
	
	if current_operation:
		current_operation.cancel = true
	for op in ready_operations:
		op.cancel = true
	for op in pending_operations:
		op.cancel = true
	
	if col_sibling:
		get_parent().remove_child(col_sibling)


func _to_string():
	return "[VoxelInstance3D:%s]" % get_instance_id()


# used by VoxelOpCreateMesh to call_deferred
func set_mesh(new_mesh:Mesh):
	mesh_child.mesh = new_mesh
	emit_signal("mesh_ready")

var my_self_bug_check_hack
func push_voxel_operation(vox_op : VoxelOperation):
	print("%s: push_voxel_operation %s" % [self,vox_op])
	my_self_bug_check_hack = self
	call_deferred("_deferred_push_voxel_op", vox_op)

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

var thread_working : Mutex

func _advance_operation_stack():
	#print("VoxelInstance3D %s: advance_operation_stack, stack: %s" % [self,str(pending_operations)])
	if not current_operation:
		#print("popping from stack %s" % str(current_operation))
		current_operation = pending_operations.pop_front()
		if current_operation:
			print("VoxelInstance3D %s: pop&run operation %s (pending_stack: %s)" % [self,current_operation, str(pending_operations)])
			match configuration.thread_mode:
				VoxelConfiguration.THREAD_MODE.NONE:
					print("%s: running operation (blocking main thread)..." % self)
					var run_start_us = Time.get_ticks_usec()
					current_operation.run_operation()
					current_operation = null
					var delta_time_us = Time.get_ticks_usec() - run_start_us
					print("%s: finished in %s seconds" % [self, delta_time_us/1000000.0])
				VoxelConfiguration.THREAD_MODE.SIMPLE:
					var thread = Thread.new()
					thread.start(_run_op_thread.bind(current_operation))
				VoxelConfiguration.THREAD_MODE.TASKSERVER:
					pass
					# TODO use TaskServer if available
		else:
			print("no current op")

func _run_op_thread(op : VoxelOperation):
	print("[Thread:%s]: running operation ..." % OS.get_thread_caller_id())
	var run_start_us = Time.get_ticks_usec()
	
	op.run_operation()
	
	var delta_time_us = Time.get_ticks_usec() - run_start_us
	print("[Thread:%s]: finished in %s seconds" % [OS.get_thread_caller_id(), delta_time_us/1000000.0])
	current_operation = null

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
	
	if col_sibling:
		if value:
			get_parent().remove_child(col_sibling)
			get_parent().add_child(col_sibling)
			col_sibling.owner = get_tree().edited_scene_root
		else:
			get_parent().remove_child(col_sibling)
			col_sibling.owner = null

func _on_voxel_configuration_changed(what):
	print("VoxelNode: _on_voxel_configuration_changed %s" % what)

	# Force recalculation of mesh
	_on_voxels_changed()

func _on_voxels_changed():
	if not my_self_bug_check_hack:
		# TODO: check if this Godot bug in signal emitting has been fixed
		print("%s: BUG_HACK: I'm not real! -> ingnoring." % self)
		return
	
	print("VoxelInstance3D %s %s: _on_voxels_changed [0]=%s" % [self,my_self_bug_check_hack,str(voxel_data.data[0])])
	
	_debug_mesh_color = Color(0.5,0,0)

	emit_signal("data_changed", "voxels")

	# recalculate Visibility if no other vox operations pending
	if not current_operation and pending_operations.is_empty():
		call_deferred("push_voxel_operation",VoxelOpVisibility.new())

func notify_visibility_calculated():
	visibility_count = vis_buffer.count(1)
		
	print("%s: visibility calculated: %s visible voxels" % [self,str(visibility_count)])
	
	_debug_mesh_color = Color(1,0.5,0)
	
	emit_signal("data_changed", "vis_buffer")
	
	# Calculate Mesh if no other operations pending
	if not current_operation and pending_operations.is_empty():
		call_deferred("push_voxel_operation",VoxelOpCreateMesh.new())


func notify_mesh_calculated():
	
	_debug_mesh_color = Color(0,0.5,0)
	
	mesh_surfaces_count = 0
	mesh_faces_count = 0
	if mesh_child.mesh:
		mesh_surfaces_count = mesh_child.mesh.get_surface_count()
		mesh_faces_count = mesh_child.mesh.get_faces().size()
	
	_debug_mesh_color = Color(0,1.0,0)
	print("%s: mesh calculated: %s surfaces, %s faces" % [self, str(mesh_surfaces_count), str(mesh_faces_count)])

	var start_time = Time.get_ticks_usec()
	if generate_collision_sibling and not col_sibling:
		col_sibling = CollisionShape3D.new()
		print("%s: Adding Collision sibling %s" % [self, col_sibling])
		get_parent().add_child(col_sibling)
		# if editor set as owner to view in scenetree
		if Engine.is_editor_hint() and VoxelHammer.show_debug_gizmos:
			col_sibling.owner = get_tree().edited_scene_root

	if col_sibling:
		# Orient as self
		# TODO check if scaled and warn that collision dont work with scaled Shapes
		col_sibling.transform = self.transform
		
		match generate_collision_sibling:
			COLLISION_MODE.NONE:
				push_warning("%s: Something wrong with logic, this should not happen!")
			COLLISION_MODE.CUBE:
				col_sibling.shape = BoxShape3D.new()
				col_sibling.shape.size = voxel_data.size
				col_sibling.translate_object_local(Vector3(voxel_data.size)/2.0)
			COLLISION_MODE.CONVEX_MESH:
				col_sibling.shape = mesh_child.mesh.create_convex_shape(true, false)
			COLLISION_MODE.CONCAVE_MESH:
				col_sibling.shape = mesh_child.mesh.create_trimesh_shape()
			_:
				push_warning("%s: Unsupported collision mode: %s!" % generate_collision_sibling)
				
		var delta_time = Time.get_ticks_usec() - start_time
		print("%s: collision shape calculated in %s seconds: %s" % [self, delta_time/1000000.0, str(col_sibling.shape)])

	_debug_mesh_color = Color(0.5,1.0,0.5)
		
	emit_signal("data_changed", "mesh")
