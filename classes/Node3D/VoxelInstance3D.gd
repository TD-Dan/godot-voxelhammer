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
		
		_on_voxel_configuration_changed()

func _on_voxel_configuration_changed(what="all"):
	#print("VoxelNode: _on_voxel_configuration_changed %s" % what)
	if what == "all" or what == "thread_mode":
		match configuration.thread_mode:
			VoxelConfiguration.THREAD_MODE.NONE:
				worker_thread = null
			VoxelConfiguration.THREAD_MODE.SIMPLE:
				if not worker_thread:
					worker_thread = Thread.new()
			VoxelConfiguration.THREAD_MODE.TASKSERVER:
				worker_thread = null
				# TODO use TaskServer if available
	# Force recalculation of mesh
	_on_voxels_changed()

@export var voxel_data : Resource = VoxelData.new(1): # : VoxelData
	set(nv):
		#print("%s: _set_voxel_data" % self)
		
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

func _on_voxels_changed():
	print("VoxelInstance3D: _on_voxels_changed")
	if not my_self_bug_check_hack:
		# TODO: check if this Godot bug in signal emitting has been fixed
		print("%s: BUG_HACK: I'm not real! -> ingnoring." % self)
		return
	
	#print("VoxelInstance3D %s %s: _on_voxels_changed [0]=%s" % [self,my_self_bug_check_hack,str(voxel_data.data[0])])
	
	_debug_mesh_color = Color(0.5,0,0)

	emit_signal("data_changed", "voxels")

	# recalculate mesh
	remesh()


@export var paint_stack : Resource  = null: #VoxelPaintStack
	set(nv):
		paint_stack = nv
		if paint_stack:
			if voxel_data:
				voxel_data.clear()
				push_voxel_operation(VoxelOpPaintStack.new(paint_stack, global_position))


var _col_sibling # only one editing this value is _update_collision_sibling!

enum COLLISION_MODE{
	NONE,
	CUBE,
	CONVEX_MESH,
	CONCAVE_MESH
}
@export var generate_collision_sibling : COLLISION_MODE = COLLISION_MODE.NONE:
	set(nv):
		generate_collision_sibling = nv
		_update_collision_sibling()



var vis_buffer : PackedByteArray = PackedByteArray()
var visibility_count = null

var smooth_buffer : PackedByteArray = PackedByteArray()

var mesh_child : MeshInstance3D

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


var worker_thread : Thread = null

var pending_operations = []
var PENDING_OPERATIONS_LIMIT = 16
var current_operation : VoxelOperation = null

func _ready():
	#print("VoxelInstance3D: _ready")
	mesh_child = get_node_or_null("VoxelMeshInstance3D")
	if not mesh_child:
		mesh_child = MeshInstance3D.new()
		mesh_child.name = "VoxelMeshInstance3D"
		add_child(mesh_child)
	
	# if in editor update owner to view it scenetree and enable selection of this object
	if Engine.is_editor_hint():
		mesh_child.owner = get_tree().edited_scene_root

	
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
	
	# Force load configuration
	_on_voxel_configuration_changed()
	
	# Calculate Visibility (which updates mesh and collision sibling) 
	#remesh()
	
	#print("VoxelInstance3D: _ready is done")

func _enter_tree():
	_update_collision_sibling() # !important! needs to be updated incase we are inside editor

func _exit_tree():
	#print("VoxelInstance3D %s: _exit_tree" % self)
	
	if current_operation:
		current_operation.cancel = true
	for op in pending_operations:
		op.cancel = true
	
	if worker_thread and worker_thread.is_started():
		worker_thread.wait_to_finish()
	
	_update_collision_sibling()  # !important! needs to be updated incase we are inside editor

func _notification(what):
	match what:
		NOTIFICATION_PARENTED:
			var parent = get_parent()
			if parent.has_signal("input_event"):
				#print("%s: parented to %s: connecting to input_event" % [self,parent])
				parent.connect("input_event", _on_input_event)
		NOTIFICATION_UNPARENTED:
			var parent = get_parent()
			if parent.has_signal("input_event"):
				#print("%s: unparented from %s: disconnecting from input_event" % [self,parent])
				parent.disconnect("input_event", _on_input_event)
		NOTIFICATION_EDITOR_PRE_SAVE:
			# Prevent debug view of _col_sibling from being saved into file
			#print("%s: PRE_SAVE")
			if _col_sibling and _col_sibling.owner:
				_col_sibling.owner = null
		NOTIFICATION_EDITOR_POST_SAVE:
			#print("%s: POST_SAVE")
			# Restore debug view of _col_sibling after save
			if _col_sibling:
				_update_collision_sibling()

func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	if event.get_class() != "InputEventMouseMotion":
		print("Got from %s: %s @ %s towards %s in %s" % [camera,event,position,normal,shape_idx])

func _to_string():
	var idstr : String = str(get_instance_id())
	return "[VoxelInstance3D..%s]" % idstr.substr(idstr.length()-4)

# Set single voxel. Thread safe. Index safe. return true on succces
func set_voxel(pos : Vector3i, value : int) -> bool:
	var ret = false
	voxel_data.data_mutex.lock()
	
	if pos.x < 0 or pos.y < 0 or pos.z < 0 or \
		pos.x >= voxel_data.size.x or pos.y >= voxel_data.size.y or pos.z >= voxel_data.size.z:
		push_warning("%s: Trying to set voxel at %s wich is out of bounds of size %s" % [self, pos, voxel_data.size])
		if Engine.is_editor_hint():
			print("%s: Trying to set voxel at %s wich is out of bounds of size %s" % [self, pos, voxel_data.size])
	else:
		voxel_data.data[voxel_data.vector3i_to_index(pos)] = value
		voxel_data.notify_data_changed()
		ret = true
	
	voxel_data.data_mutex.unlock()
	return ret

# used by VoxelOpCreateMesh to call_deferred
func set_mesh(new_mesh:Mesh):
	mesh_child.mesh = new_mesh
	emit_signal("mesh_ready")

# Force redraw of mesh
func remesh():
	push_voxel_operation(VoxelOpVisibility.new())

var my_self_bug_check_hack
func push_voxel_operation(vox_op : VoxelOperation):
	#print("%s: push_voxel_operation %s, pending operations: %s" % [self,vox_op, pending_operations.size()])
	my_self_bug_check_hack = self
	if pending_operations.size() < PENDING_OPERATIONS_LIMIT:
		call_deferred("_deferred_push_voxel_op", vox_op)
	else:
		push_error("%s: Too many pending operations (PENDING_OPERATIONS_LIMIT=%s)." % [self,PENDING_OPERATIONS_LIMIT])

func _deferred_push_voxel_op(vox_op : VoxelOperation):
	# This is problematic: we will never update the whole mesh when cpu limited if we do this
	# Remove all higher and equal state calculations from pending operations, as they are now made invalid
#	if current_operation and current_operation.calculation_level >= vox_op.calculation_level:
#		print("removing higher or equal current op: %s in favor of %s" % [current_operation, vox_op])
#		current_operation.cancel = true
#		current_operation = null
#	for op in pending_operations:
#		if op.calculation_level >= vox_op.calculation_level:
#			print("removing higher or equal pending op: %s in favor of %s" % [op, vox_op])
#			op.cancel = true
#			pending_operations.erase(op)
	
	vox_op.voxel_instance = self
	
	pending_operations.push_back(vox_op)
	
	_advance_operation_stack()


func _advance_operation_stack():
	#print("VoxelInstance3D %s: advance_operation_stack, stack: %s" % [self,str(pending_operations)])
	if not current_operation:
		#print("popping from stack %s" % str(current_operation))
		current_operation = pending_operations.pop_front()
		if current_operation:
			#print("VoxelInstance3D %s: pop&run operation %s (pending_stack: %s)" % [self,current_operation, str(pending_operations)])
			match configuration.thread_mode:
				VoxelConfiguration.THREAD_MODE.NONE:
					#print("%s: running operation (blocking main thread)..." % self)
					var run_start_us = Time.get_ticks_usec()
					current_operation.run_operation()
					var delta_time_us = Time.get_ticks_usec() - run_start_us
					print("%s: finished %s in %s seconds" % [self, current_operation, delta_time_us/1000000.0])
					current_operation = null
				VoxelConfiguration.THREAD_MODE.SIMPLE:
					#var run_start_us = Time.get_ticks_usec()
					worker_thread.start(_run_op_thread.bind(current_operation))
					#var delta_time_us = Time.get_ticks_usec() - run_start_us
					#print("%s: thread start took %s seconds" % [self, delta_time_us/1000000.0])
				VoxelConfiguration.THREAD_MODE.TASKSERVER:
					pass
					# TODO use TaskServer if available
		else:
			print("no current op")

# Run operation in local simple thread mode
func _run_op_thread(op : VoxelOperation):
	#print("[Thread:%s]: running operation ..." % OS.get_thread_caller_id())
	var run_start_us = Time.get_ticks_usec()
	
	op.run_operation()
	
	var delta_time_us = Time.get_ticks_usec() - run_start_us
	
	var idstr = str(OS.get_thread_caller_id())
	idstr = idstr.substr(idstr.length()-4)
	if op.cancel:
		print("[Thread..%s]: CANCELLED %s in %s seconds" % [idstr, op, delta_time_us/1000000.0])
	else:		
		print("[Thread..%s]: finished %s in %s seconds" % [idstr, op, delta_time_us/1000000.0])
	
	call_deferred("join_worker_thread")

func join_worker_thread():
	#print("joining")
	worker_thread.wait_to_finish()
	current_operation = null

func notify_visibility_calculated():
	visibility_count = vis_buffer.count(1)
		
	#print("%s: visibility calculated: %s visible voxels" % [self,str(visibility_count)])
	
	_debug_mesh_color = Color(1,0.5,0)
	
	emit_signal("data_changed", "vis_buffer")
	
	# Calculate Mesh
	call_deferred("push_voxel_operation",VoxelOpCreateMesh.new())


func notify_mesh_calculated():
	
	_debug_mesh_color = Color(0,0.5,0)
	
	mesh_surfaces_count = 0
	mesh_faces_count = 0
	if mesh_child.mesh:
		mesh_surfaces_count = mesh_child.mesh.get_surface_count()
		mesh_faces_count = mesh_child.mesh.get_faces().size()
	
	_debug_mesh_color = Color(0,1.0,0)
	#print("%s: mesh calculated: %s surfaces, %s faces" % [self, str(mesh_surfaces_count), str(mesh_faces_count)])
	
	_update_collision_sibling()
	
	emit_signal("data_changed", "mesh")


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


func _update_collision_sibling():
	if not is_inside_tree():
		#print("Not inside tree: do nothing.")
		return
	if not generate_collision_sibling:
		if _col_sibling:
			_col_sibling.queue_free() # removes from parent so no need to call get_parent().remove_child(_col_sibling)
			_col_sibling = null
	else: # generate_collision_sibling
		if not _col_sibling:
			if Engine.is_editor_hint():
				if get_parent() == get_tree().edited_scene_root:
					push_warning("Cant add collision sibling to top level node! Add this node as a child to a PhysicsBody3D Node. Set to NONE.")
					generate_collision_sibling = COLLISION_MODE.NONE
					return
			_col_sibling = get_parent().get_node_or_null("VoxelShape3D")
			if _col_sibling:
				print("Found collision sibling from parent")
				_col_sibling = get_parent().get_node("VoxelShape3D")
			else:
				_col_sibling = CollisionShape3D.new()
				_col_sibling.name = "VoxelShape3D"
				print("%s: Adding Collision sibling %s" % [self, _col_sibling])
				get_parent().call_deferred("add_child",_col_sibling)
		
		# if in editor update owner to view in scenetree
		if Engine.is_editor_hint():
			if _debug_mesh_visible:
				_col_sibling.owner = get_tree().edited_scene_root
			else:
				_col_sibling.owner = null
		
		# generate the collision shape
		var start_time = Time.get_ticks_usec()
		# Orient same as self
		# TODO check if scaled and warn that collision dont work with scaled Shapes
		_col_sibling.transform = self.transform
		_col_sibling.shape = null
		
		match generate_collision_sibling:
			COLLISION_MODE.NONE:
				push_warning("%s: Something wrong with logic, this should not happen!")
			COLLISION_MODE.CUBE:
				_col_sibling.shape = BoxShape3D.new()
				_col_sibling.shape.size = voxel_data.size
				_col_sibling.translate_object_local(Vector3(voxel_data.size)/2.0)
			COLLISION_MODE.CONVEX_MESH:
				if mesh_child and mesh_child.mesh:
					_col_sibling.shape = mesh_child.mesh.create_convex_shape(true, false)
			COLLISION_MODE.CONCAVE_MESH:
				if mesh_child and mesh_child.mesh:
					_col_sibling.shape = mesh_child.mesh.create_trimesh_shape()
			_:
				push_warning("%s: Unsupported collision mode: %s!" % generate_collision_sibling)
				
		var delta_time = Time.get_ticks_usec() - start_time
		if _col_sibling.shape:
			print("%s: collision shape calculated in %s seconds: %s" % [self, delta_time/1000000.0, str(_col_sibling.shape)])
			_debug_mesh_color = Color(0.5,1.0,0.5)


func _on_show_debug_gizmos_changed(value):
	#print("VoxelInstance3D: Changing debug mesh visibility to " + str(value))
	_debug_mesh_visible = value
	
	_update_collision_sibling() # ! important ! updates editor as owner of _col_sibling
