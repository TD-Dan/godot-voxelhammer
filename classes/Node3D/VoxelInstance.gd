@tool

extends Node3D

class_name VoxelInstance

## VoxelData as a mesh instance inside SceneTree
##
## Uses settings from VoxelConfiguration to generate and display a Mesh out of VoxelData
##

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
				pass # dont bother to delete worker_thread
			VoxelConfiguration.THREAD_MODE.SIMPLE:
				if not worker_thread:
					worker_thread = Thread.new()
			VoxelConfiguration.THREAD_MODE.WORKER_THREAD_POOL:
				pass # dont bother to delete worker_thread
	
	# Force recalculation of mesh
	_on_voxels_changed()

@export var voxel_data : Resource: # VoxelData
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
	#print("%s: _on_voxels_changed" % self)
	#if not my_self_bug_check_hack:
		# TODO: check if this Godot bug in signal emitting has been fixed
	#	print("%s: BUG_HACK: I'm not real! -> ingnoring." % self)
	#	return
	
	#print("%s: %s: _on_voxels_changed [0]=%s" % [self,my_self_bug_check_hack,str(voxel_data.data[0])])
	
	_debug_mesh_color = Color(0.5,0,0)

	emit_signal("data_changed", "voxels")

	# recalculate mesh
	remesh()


@export var paint_stack : Resource  = null: #VoxelPaintStack
	set(nv):
		# Disconnect from previous paint_stack
		if paint_stack:
			if paint_stack.operation_stack_changed.is_connected(_paint_stack_changed):
				paint_stack.operation_stack_changed.connect(_paint_stack_changed)
		
		paint_stack = nv
		
		# Connect to new paint_stack
		if paint_stack:
			if not paint_stack.operation_stack_changed.is_connected(_paint_stack_changed):
				paint_stack.operation_stack_changed.connect(_paint_stack_changed)
		
		if not voxel_data:
			push_error("%s: Please create voxel_data before changing paint_stack!" % self)
		voxel_data.clear()
		apply_paintstack()

func _paint_stack_changed():
	apply_paintstack()


func apply_paintstack(draw_stack : VoxelPaintStack = null):
	if not draw_stack: draw_stack = paint_stack
	if draw_stack:
		if voxel_data:
			push_voxel_operation(VoxelOpPaintStack.new(draw_stack))


# Collision object that is added to the parent 
var _col_sibling

## Type of collision shape to use with CollisionObject3D and its subclasses
enum COLLISION_MODE{
	NONE,			## No collision object is created
	CUBE,			## Simple cube encasing the whole voxel shape
	CONVEX_MESH,	## Convex mesh (no indents)
	CONCAVE_MESH	## Concave mesh that matches the actual voxel data, *might* be slow to process
}

var _generate_collision_sibling : COLLISION_MODE = COLLISION_MODE.NONE
## Generate collision shape to use with CollisionObject3D and its subclasses
@export var generate_collision_sibling : COLLISION_MODE = COLLISION_MODE.NONE:
	set(nv):
		_generate_collision_sibling = nv
		_update_collision_sibling()
	get:
		return _generate_collision_sibling

## Mesh scale. When other than 1.0, mesh type collision siblings are not available, as Godot does not support scaled collision shapes
@export_range(0.1, 10.0, 0.1) var mesh_scale : float = 1.0:
	set(nv):
		mesh_scale = nv
		if mesh_child:
			mesh_child.scale = Vector3(mesh_scale,mesh_scale,mesh_scale)
		_update_collision_sibling()


var data_buffer : PackedInt64Array = PackedInt64Array()
var data_buffer_dimensions : Vector3i = Vector3i()
var data_buffer_mutex = Mutex.new()

var blend_buffer : PackedFloat32Array = PackedFloat32Array()

var vis_buffer : PackedByteArray = PackedByteArray()
var visibility_count = null


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

var worker_pool_task_number


var pending_operations = []
var PENDING_OPERATIONS_LIMIT = 3
var current_operation : VoxelOperation = null

func _ready():
	#print("%s: _ready" % self)
	
	if not voxel_data:
		var voxel_hammer_autoload = get_node_or_null("/root/VoxelHammer")
		if voxel_hammer_autoload:
			voxel_data = load(voxel_hammer_autoload.plugin_directory + "res/vox_Letter_M_on_block.tres").duplicate()
	
	_establish_mesh_child()
	
	# Connect to VoxelHammer autoload
	var vh = get_node_or_null("/root/VoxelHammer")
	if vh:
		_debug_mesh_visible = vh.show_debug_gizmos
		vh.connect("show_debug_gizmos_changed", _on_show_debug_gizmos_changed)
			
		if not configuration:
			configuration = vh.default_configuration
	
	# TODO: If TaskServer plugin is present connect to it
	#var th_autoload_global = get_node_or_null("/root/TaskHammer")
	#if th_autoload_global:
		#print("Found TaskHammer plugin! Integrating...")
	#else:
		#if configuration.thread_mode == VoxelConfiguration.THREAD_MODE.TASKSERVER:
			#push_warning("(OPTIONAL) TaskServer Global Autoload NOT found. TaskServer plugin installed? Falling back to simple thread execution..")
			#configuration.thread_mode = VoxelConfiguration.THREAD_MODE.SIMPLE
	
	# Force load configuration, wich will initiate mesh calculation
	_on_voxel_configuration_changed()
	
	#print("%s: _ready is done" % self)


## Create new or find existing mesh_child object
func _establish_mesh_child():
	mesh_child = get_node_or_null("VoxelMeshInstance3D")
	if not mesh_child:
		mesh_child = MeshInstance3D.new()
		mesh_child.name = "VoxelMeshInstance3D"
		call_deferred("add_child", mesh_child)
	
	mesh_child.position = Vector3.ZERO
	mesh_child.rotation = Vector3.ZERO
	mesh_child.scale = Vector3(mesh_scale,mesh_scale,mesh_scale)
	# if in editor update owner to view it scenetree and enable selection of this object
	if Engine.is_editor_hint() and is_inside_tree():
		mesh_child.owner = self
		#call_deferred("_set_editor_as_owner", mesh_child)


#func _enter_tree():
#	pass


func _exit_tree():
	#print("%s: _exit_tree" % self)
	
	if current_operation:
		current_operation.cancel = true
	for op in pending_operations:
		op.cancel = true
	
	if worker_thread and worker_thread.is_started():
		worker_thread.wait_to_finish()
	
	if worker_pool_task_number:
		WorkerThreadPool.wait_for_task_completion(worker_pool_task_number)
		worker_pool_task_number = null
	
	_update_collision_sibling()  # !important! needs to be updated incase we are inside editor. This removes the sibling alongside the VoxelInstance.


func _notification(what):
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			#print("%s: PRE_SAVE")
			#Exclude children from save file
			if mesh_child:
				mesh_child.owner = null
				#mesh_child.queue_free()
				#mesh_child = null
			if _col_sibling:
				_col_sibling.owner = null
				#_col_sibling.queue_free()
				#_col_sibling = null
		NOTIFICATION_EDITOR_POST_SAVE:
			#print("%s: POST_SAVE")
			# Restore editor view of children
			if mesh_child:
				mesh_child.owner = self
			if _col_sibling:
				_col_sibling.owner = self


func _to_string():
	var idstr : String = str(get_instance_id())
	return "[VoxelInstance%s]" % idstr.substr(idstr.length()-4)


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
	_establish_mesh_child()
	mesh_child.mesh = new_mesh
	#print("MESH READY")
	emit_signal("mesh_ready")


# Force redraw of mesh
func remesh():
	push_voxel_operation(VoxelOpVisibility.new(), true, false)


var my_self_bug_check_hack
func push_voxel_operation(vox_op : VoxelOperation, in_front = false, respect_limits=true):
	#print("%s: push_voxel_operation %s, pending operations: %s" % [self,vox_op, pending_operations.size()])
	my_self_bug_check_hack = self
	
	if respect_limits and pending_operations.size() > PENDING_OPERATIONS_LIMIT:
		#push_error("%s: Too many pending operations (PENDING_OPERATIONS_LIMIT=%s)." % [self,PENDING_OPERATIONS_LIMIT])
		return
	
	call_deferred("_deferred_push_voxel_op", vox_op, in_front)


func _deferred_push_voxel_op(vox_op : VoxelOperation, in_front):
	
	vox_op.voxel_instance = self
	
	if in_front:
		pending_operations.push_front(vox_op)
	else:
		pending_operations.push_back(vox_op)
	
	_advance_operation_stack()


func _advance_operation_stack():
	#if not is_inside_tree():
	#	return true
		
	#print("%s: advance_operation_stack, stack: %s" % [self,str(pending_operations)])
	if not current_operation:
		#print("popping from stack %s" % str(current_operation))
		current_operation = pending_operations.pop_front()
		if current_operation:
			#print("%s: pop&run operation %s (pending_stack: %s)" % [self,current_operation, str(pending_operations)])
			match configuration.thread_mode:
				VoxelConfiguration.THREAD_MODE.NONE:
					print("%s: running operation (blocking main thread)..." % self)
					var run_start_us = Time.get_ticks_usec()
					current_operation.prepare_run_operation()
					current_operation.run_operation()
					var delta_time_us = Time.get_ticks_usec() - run_start_us
					print("%s: finished %s in %s seconds" % [self, current_operation, delta_time_us/1000000.0])
					current_operation = null
				VoxelConfiguration.THREAD_MODE.SIMPLE:
					#var run_start_us = Time.get_ticks_usec()
					current_operation.prepare_run_operation()
					worker_thread.start(_run_op_thread.bind(current_operation))
					#var delta_time_us = Time.get_ticks_usec() - run_start_us
					#print("%s: thread start took %s seconds" % [self, delta_time_us/1000000.0])
				VoxelConfiguration.THREAD_MODE.WORKER_THREAD_POOL:
					current_operation.prepare_run_operation()
					worker_pool_task_number = WorkerThreadPool.add_task(_run_op_worker_pool.bind(current_operation))
					
		#else:
		#	print("no current op")


# Run operation in local simple thread mode
func _run_op_thread(op : VoxelOperation):
	#print("[Thread:%s]: running operation ..." % OS.get_thread_caller_id())
	#var run_start_us = Time.get_ticks_usec()
	if not op.cancel:
		op.run_operation()
	
	#var delta_time_us = Time.get_ticks_usec() - run_start_us
	
	# string operations here add frame stutter, comment out for extra speed
	#var idstr = str(OS.get_thread_caller_id())
	#idstr = idstr.substr(idstr.length()-4)
	#if op.cancel:
	#	print("[Thread..%s]: CANCELLED %s in %s seconds" % [idstr, op, delta_time_us/1000000.0])
	#else:		
	#	print("[Thread..%s]: finished %s in %s seconds" % [idstr, op, delta_time_us/1000000.0])
	
	call_deferred("join_worker_thread")


func join_worker_thread():
	worker_thread.wait_to_finish()
	current_operation = null
	_advance_operation_stack()


# Run operation in local simple thread mode
func _run_op_worker_pool(op : VoxelOperation):
	#print("[WorkerThreadPool:%s]: running operation ...")

	if not op.cancel:
		op.run_operation()
	
	call_deferred("join_worker_pool")


func join_worker_pool():
	WorkerThreadPool.wait_for_task_completion(worker_pool_task_number)
	current_operation = null
	worker_pool_task_number = null
	_advance_operation_stack()
	
	
func notify_visibility_calculated():
	visibility_count = vis_buffer.count(1)
	
	#print("%s: visibility calculated: %s visible voxels" % [self,str(visibility_count)])
	
	_debug_mesh_color = Color(1,0.5,0)
	
	emit_signal("data_changed", "vis_buffer")
	
	# Calculate Mesh
	call_deferred("push_voxel_operation", VoxelOpCreateMesh.new(), true, false)


func notify_mesh_calculated():
	
	_debug_mesh_color = Color(0,0.5,0)
	
	mesh_surfaces_count = 0
	mesh_faces_count = 0
	if mesh_child.mesh and Engine.is_editor_hint():
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
	
	var size = voxel_data.size * mesh_scale
	
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
	var voxel_hammer_autoload = get_node_or_null("/root/VoxelHammer")
	if voxel_hammer_autoload:
		_debug_mesh_child.mesh.surface_set_material(0, load(voxel_hammer_autoload.plugin_directory+"res/line.tres"))


func _update_collision_sibling():
	# Clear previous collision sibling
	if _col_sibling and _col_sibling != null:
		if get_parent():
				get_parent().remove_child.call_deferred(_col_sibling)
		_col_sibling.queue_free()
		_col_sibling = null
	
	# Keep tree clean of any leftover nodes
	if get_parent():
		var old_sibling = get_parent().get_node_or_null("VoxelShape3D")
		if old_sibling:
			#print("Removing previous collision sibling from parent")
			old_sibling.queue_free()
	
	if not is_inside_tree():
		#print("Not inside tree: do nothing.")
		return
	
	if mesh_scale != 1.0:
		if _generate_collision_sibling > COLLISION_MODE.CUBE:
			push_warning("Mesh collision is not supported for scaled meshes. This is a Godot limitation. Falling back to Cube collision. Set 'Mesh Scale' to 1.0 to enable mesh collisions.")
			_generate_collision_sibling = COLLISION_MODE.CUBE
				
	if _generate_collision_sibling:
		if Engine.is_editor_hint():
			if self == get_tree().edited_scene_root:
				push_warning("Cant add collision sibling to top level node! Add this node as a child to a PhysicsBody3D Node to generate a collision sibling. Set to NONE.")
				_generate_collision_sibling = COLLISION_MODE.NONE
				return
		
		
		_col_sibling = CollisionShape3D.new()
		_col_sibling.name = "VoxelShape3D"
		#print("%s: Adding Collision sibling %s" % [self, _col_sibling])
		get_parent().call_deferred("add_child",_col_sibling)
		
		
		# generate the collision shape
		var start_time = Time.get_ticks_usec()
		# Orient same as self
		# TODO check if scaled and warn that collision dont work with scaled Shapes
		_col_sibling.transform = self.transform
		_col_sibling.shape = null
		
		match _generate_collision_sibling:
			COLLISION_MODE.NONE:
				push_warning("%s: Something wrong with logic, this should not happen!")
			COLLISION_MODE.CUBE:
				_col_sibling.shape = BoxShape3D.new()
				_col_sibling.shape.size = voxel_data.size * mesh_scale
				_col_sibling.translate_object_local(Vector3(voxel_data.size * mesh_scale)/2.0)
			COLLISION_MODE.CONVEX_MESH:
				if mesh_child and mesh_child.mesh:
					_col_sibling.shape = mesh_child.mesh.create_convex_shape(true, false)
			COLLISION_MODE.CONCAVE_MESH:
				if mesh_child and mesh_child.mesh:
					_col_sibling.shape = mesh_child.mesh.create_trimesh_shape()
			_:
				push_warning("%s: Unsupported collision mode: %s!" % _generate_collision_sibling)
				
		# if in editor update owner to view in scenetree
		if Engine.is_editor_hint():
			_col_sibling.owner = self
			#call_deferred("_set_editor_as_owner", _col_sibling)
		
		var delta_time = Time.get_ticks_usec() - start_time
		if _col_sibling.shape:
			#print("%s: collision shape calculated in %s seconds: %s" % [self, delta_time/1000000.0, str(_col_sibling.shape)])
			_debug_mesh_color = Color(0.5,1.0,0.5)


func _on_show_debug_gizmos_changed(value):
	#print("%s: Changing debug mesh visibility to %s" %[sef,str(value)])
	_debug_mesh_visible = value
	
	_update_collision_sibling() # ! important ! updates editor as owner of _col_sibling
