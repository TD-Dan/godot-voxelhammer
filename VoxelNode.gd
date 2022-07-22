@tool

extends Node3D

class_name VoxelNode

# emitted when mesh (+ uv + normals and all) is complete
signal mesh_ready

@export var configuration : Resource:#VoxelConfiguration:
	set(v):
		#print("set configuration to %s" % new_value)
		if configuration:
			if configuration.is_connected("voxel_configuration_changed", _on_voxel_configuration_changed):
				configuration.disconnect("voxel_configuration_changed", _on_voxel_configuration_changed)
		
		configuration = v
		
		if configuration:
			if not configuration.is_connected("voxel_configuration_changed", _on_voxel_configuration_changed):
				configuration.connect("voxel_configuration_changed", _on_voxel_configuration_changed)
		
		# force redraw of mesh
		if voxel_data and voxel_data.calculation_state > VoxelData.CALC_STATE.MESH:
			voxel_data.set_state(VoxelData.CALC_STATE.MESH-1)

@export var voxel_data : Resource = VoxelData.new(): # : VoxelData
	set(v):
		#print("_set_voxel_data")
		if voxel_data:
			if voxel_data.is_connected("voxel_data_changed", _on_voxel_data_changed):
				voxel_data.disconnect("voxel_data_changed", _on_voxel_data_changed)
		
		voxel_data = v
		
		if voxel_data:
			if not voxel_data.is_connected("voxel_data_changed", _on_voxel_data_changed):
				voxel_data.connect("voxel_data_changed", _on_voxel_data_changed)

var paint_stack : VoxelPaintStack = null:
	set(v):
		paint_stack = v
		if paint_stack:
			if voxel_data:
				voxel_data.clear()

 # apply voxel paint stack in local coordinates instead of world coordinates
@export var voxel_paint_local = true

enum DISTANCE_MODE {
	OFF,
	ORIGO,
	CAMERA,
	NODE
}

@export var distance_tracking : DISTANCE_MODE = DISTANCE_MODE.OFF:
	set(v):
		distance_tracking = v
		if not distance_tracking and mesh_child and not mesh_child.visible:
			mesh_child.visible = true

@export var use_qubic_distance = false
var _distance_update_skip_frames : int = 30
var _skip_counter : int = 0
@export var distance_update_interval_seconds = 1.0:
	set(v):
		distance_update_interval_seconds = max(1.0/60.0, v)
		_distance_update_skip_frames = 60.0 * distance_update_interval_seconds

var distance_tracked_node : Node3D = null
var distance_to_tracked : float = 0

@export var lod_tracking = false:
	set(v):
		lod_tracking = v
		if lod_tracking and not distance_tracking:
			push_warning("VoxelNode: lod_tracking enabled while distance_tracking is OFF! LOD tracking will not update!")

@export var lod_distance_min = 0.0
@export var lod_distance_max = 1000.0


# do_x : Helpers for development debugging
#

@export var do_clear = false:
	set(v):
		if v == false:
			do_clear = false
			return
		
		if voxel_data:
			voxel_data.clear()
		
		if mesh_child:
			mesh_child.mesh = null
		
		if paint_stack:
			paint_stack = null
		
		do_clear = false

@export var do_fill = false:
	set(v):
		if v == false:
			do_fill = false
			return
		
		add_voxel_op(VoxelOpFill.new(self.voxel_data, self.configuration, 1, 1))
	
		do_fill = false

@export var do_sphere = false:
	set(v):
		if v == false:
			do_sphere = false
			return
		
		var center = Vector3(voxel_data.voxel_count.x/2,voxel_data.voxel_count.y/2,voxel_data.voxel_count.z/2)
		var radius = voxel_data.smallest_count/2
		add_voxel_op(VoxelOpFillSphere.new(self.voxel_data, self.configuration, 1, 1, center, radius))
		
		do_sphere = false

@export var do_plane = false:
	set(v):
		if v == false:
			do_plane = false
			return
		
		paint_stack = VoxelPaintStack.new()
		paint_stack.add_paint_operation(PaintOpPlane.new(VoxelPaintStack.BLEND_MODE.NORMAL, 2, true, -100, 0))
		paint_stack.add_paint_operation(PaintOpPlane.new(VoxelPaintStack.BLEND_MODE.NORMAL, 1, false, 1, 2))
		paint_stack.add_paint_operation(PaintOpPlane.new(VoxelPaintStack.BLEND_MODE.NORMAL, 2, true, 5, 8))
		paint_stack.add_paint_operation(PaintOpPlane.new(VoxelPaintStack.BLEND_MODE.NORMAL, 3, false, 10, 24))
		
		do_plane = false
		
		_set_do_clear(true)

var mesh_child

var task_server_client

var mesh_debug
var debug_mesh_color = Color(0,0,0):
	set(v):
		debug_mesh_color = v
		#print("set debug mesh color to %s" % debug_mesh_color)
		if show_debug_mesh:
			create_debug_mesh()
		else:
			if mesh_debug:
				mesh_debug.mesh = null
var show_debug_mesh = false:
	set(v):
		show_debug_mesh = v
		if show_debug_mesh:
			create_debug_mesh()
		else:
			if mesh_debug:
				mesh_debug.mesh = null


var use_camera_for_priority = true

var pending_operations = []
var current_operation = null
var ready_operations = []

var mesh_is_ready = false




func _init():
	#print("VoxelNode init")
	if not configuration:
		configuration = VoxelHammer.default_configuration


func _ready():
	set_physics_process(true)
	
	#print("VoxelNode: _ready")
	show_debug_mesh = VoxelHammer.show_debug_gizmos
	VoxelHammer.connect("show_debug_gizmos_changed", self, "_on_show_debug_gizmos_changed")
	
	task_server_client = TaskServerClient.new()
	#task_server_client.process_locally = true
	add_child(task_server_client)
	task_server_client.connect("work_ready",self,"on_work_is_ready")
	
	mesh_child = MeshInstance.new()
	add_child(mesh_child)
	
	#if voxel_data.calculation_state >= VoxelData.CALC_STATE.MESH:
	#	voxel_data.replace_mesh(null)

	if not voxel_data.is_connected("voxel_data_changed", self, "_on_voxel_data_changed"):
		voxel_data.connect("voxel_data_changed", self, "_on_voxel_data_changed")
	
	if not configuration.is_connected("voxel_configuration_changed", self, "_on_voxel_configuration_changed"):
		configuration.connect("voxel_configuration_changed", self, "_on_voxel_configuration_changed")
	
	advance_calculation_state()
	
	#print("VoxelNode: _ready is done")


func _physics_process(delta):
	if distance_tracking:
		_skip_counter += 1
		if _skip_counter >= _distance_update_skip_frames:
			_skip_counter = 0
			update_distance_tracking()


# TODO Can this function be implemented with signals also? Would be cleaner and less call overhead
func _process(delta):
	var rop = ready_operations.pop_front()
	if rop:
		property_list_changed_notify()
		current_operation = null
		#print("VoxelNode: current op ready")
		advance_calculation_state()

	if not current_operation:
		current_operation = pending_operations.pop_front()
		if current_operation:
			if task_server_client:
				task_server_client.post_work(current_operation)


func _exit_tree():
	#print("cancel pending work items")
	if current_operation:
		current_operation.cancel = true
	for w_item in ready_operations:
		w_item.cancel = true
	for w_item in pending_operations:
		w_item.cancel = true


func update_distance_tracking():
	var trackpoint = -voxel_data.real_size/2
	match distance_tracking:
		DISTANCE_MODE.CAMERA:
			if get_viewport().get_camera():
				trackpoint = get_viewport().get_camera().translation - voxel_data.real_size/2
		DISTANCE_MODE.NODE:
			if distance_tracked_node:
				trackpoint = distance_tracked_node.global_transform.origin - voxel_data.real_size/2
	if use_qubic_distance:
		# use biggest of all distances
		distance_to_tracked = max(max(abs(global_transform.origin.x - trackpoint.x), abs(global_transform.origin.y - trackpoint.y)), abs(global_transform.origin.z - trackpoint.z))
	else:
		distance_to_tracked = (global_transform.origin - trackpoint).length()
	
	if lod_tracking and mesh_child:
		if mesh_child.visible and (distance_to_tracked < lod_distance_min or distance_to_tracked > lod_distance_max):
			mesh_child.visible = false
			#print("hiding due to lod")
			#update task priorities, effectively delaying them
		elif not mesh_child.visible and (distance_to_tracked >= lod_distance_min and distance_to_tracked <= lod_distance_max):
			mesh_child.visible = true
			#print("showing due to lod")
	
	if current_operation:
		current_operation.priority = distance_to_tracked
	for op in pending_operations:
		op.priority = distance_to_tracked


func advance_calculation_state():
	#print("VoxelNode: Advance calculation state from %s" % VoxelData.CALC_STATE.keys()[voxel_data.calculation_state])
	#print_stack()
	
	# Cancel all operations creater than new calculation state
	for op in pending_operations + [current_operation] + ready_operations:
		if op and op.calculation_level > voxel_data.calculation_state:
			if op.calculation_level > VoxelData.CALC_STATE.VOXEL: # Dont cancel voxel operations
				op.cancel = true
	
	#Advance one state further on mesh calculation
	match voxel_data.calculation_state:
		
		VoxelData.CALC_STATE.INIT:
			_set_debug_mesh_color(Color(0.5,0,0))
			mesh_is_ready = false
			if paint_stack:
				var position_offset = Vector3(0,0,0)
				if !voxel_paint_local:
					position_offset = global_transform.origin * voxel_data.voxel_scale
				add_voxel_op(VoxelOpPaintStack.new(self.voxel_data, configuration, paint_stack, position_offset))
		
		VoxelData.CALC_STATE.VOXEL:
			# Voxel data has been set
			_set_debug_mesh_color(Color(1,0.5,0))
			mesh_is_ready = false
			
			# Advance to VIS state if 
			#  - no additional VOXEL level operations pending
			#  - vis calculation not already waiting
			var do_vis = true
			for op in pending_operations + [current_operation] + ready_operations:
				if op:
					if op.calculation_level <= VoxelData.CALC_STATE.VIS:
						do_vis = false
			
			if do_vis:
				add_voxel_op(VoxelOpVisibility.new(self.voxel_data, self.configuration))
		
		VoxelData.CALC_STATE.VIS:
			# Voxel visibility has been calculated
			_set_debug_mesh_color(Color(1,1,0))
			mesh_is_ready = false
			
			# Advance to MESH state if 
			#  - no additional VIS level operations pending
			#  - mesh calculation not already waiting
			var do_mesh = true
			for op in pending_operations + [current_operation] + ready_operations:
				if op:
					if op.calculation_level <= VoxelData.CALC_STATE.MESH:
						do_mesh = false
			
			if do_mesh:
				add_voxel_op(VoxelOpCreateMesh.new(self.voxel_data,self.configuration))
		
		VoxelData.CALC_STATE.MESH:
			# Voxel mesh has been calculated
			_set_debug_mesh_color(Color(0,0,1))
			mesh_is_ready = false
			
			# Advance to UV state if 
			#  - no additional MESH level operations pending
			#  - uv calculation not already waiting
			var do_uv = true
			for op in pending_operations + [current_operation] + ready_operations:
				if op:
					if op.calculation_level <= VoxelData.CALC_STATE.UV:
						do_uv = false
			
			if do_uv:
				add_voxel_op(VoxelOpCreateUV.new(self.voxel_data, self.configuration))
			
		VoxelData.CALC_STATE.UV:
			if not mesh_is_ready:
				mesh_is_ready = true
				_set_debug_mesh_color(Color(1,1,1,0.25))
				emit_signal("mesh_ready")


func add_voxel_op(vox_op : VoxelOperation):
	call_deferred("_deferred_add_voxel_op", vox_op)

func _deferred_add_voxel_op(vox_op : VoxelOperation):
	#print("Add voxel op: %s" % vox_op.to_string())
	update_distance_tracking()
	vox_op.priority = distance_to_tracked
	
	pending_operations.push_back(vox_op)


func on_work_is_ready(work_item):
	#print("!!! VoxelNode got work item %s back!" % work_item.ticket)
	
	pending_operations.erase(work_item)
	ready_operations.push_back(work_item)


func create_debug_mesh():
	#print("Creating debug mesh...")
	if not mesh_debug:
		mesh_debug = MeshInstance.new()
		add_child(mesh_debug)
	
	var size = voxel_data.real_size
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.add_color(debug_mesh_color)
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
	
	mesh_debug.mesh = st.commit()
	mesh_debug.mesh.surface_set_material(0, load("res://addons/voxel_hammer/res/line.tres"))


func _on_show_debug_gizmos_changed(value):
	_set_show_debug_mesh(value)

func _on_use_camera_for_priority_changed(value):
	use_camera_for_priority = value

func _on_voxel_configuration_changed(what):
	#print("VoxelNode: _on_voxel_configuration_changed %s" % what)
	var recalc_mesh = false
	match what:
		"materials":
			#print("on vh materials changed")
			# if mesh is present update only materials
			# if mesh is not present no need to do anything
			if voxel_data.calculation_state >= VoxelData.CALC_STATE.MESH:
				for i in range(voxel_data.material_table.size()):
					var si = voxel_data.material_table[i]
					if si > configuration.materials.size():
						si = 0
					mesh_child.set_surface_material(i, configuration.materials[si])
		"voxel_base_size":
			recalc_mesh = true
		"mesh_mode":
			recalc_mesh = true
		"accel_mode":
			recalc_mesh = true
	
	# force recalculation of mesh
	if recalc_mesh:
		if voxel_data.calculation_state >= VoxelData.CALC_STATE.MESH:
			voxel_data.set_state(VoxelData.CALC_STATE.MESH-1)
			advance_calculation_state()


func _on_voxel_data_changed(what):
	#print("VoxelNode: _on_voxel_data_changed %s" % VoxelData.CALC_STATE.keys()[what])
	match what:
		
		VoxelData.CALC_STATE.MESH:
			if voxel_data.mesh:
				mesh_child.mesh = voxel_data.mesh
			else:
				print("VoxelNode: setting a null mesh")
			
#			print("VoxelNode %s" % voxel_data.mesh)
#			for i in range(voxel_data.material_table.size()):
#				var si = voxel_data.material_table[i]
#				if si >= configuration.materials.size():
#					si = 0
#				mesh_child.set_surface_material(i, configuration.materials[si])
		
		VoxelData.CALC_STATE.UV:
			if voxel_data.mesh:
				mesh_child.mesh = voxel_data.mesh
			else:
				print("VoxelNode: setting a null uv mesh")
		
#			for i in range(voxel_data.material_table.size()):
#				var si = voxel_data.material_table[i]
#				if si >= configuration.materials.size():
#					si = 0
#				mesh_child.set_surface_material(i, configuration.materials[si])
	
	advance_calculation_state()
