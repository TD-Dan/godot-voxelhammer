@tool

extends Resource

class_name VoxelData


signal voxel_data_changed(what)

# Sketch for a compact voxel representation
# 64 bits available / voxel
#enum CHANNEL {
#	MATERIAL, # 10 bits, 1024 materials, 0 for empty
#	SMOOTH = 1 << 11, # 4 bits, 8 levels of normal smoothing
#	VISIBILE = 1 << 12, # 1 bit, visibility flag set if hidden inside
#	SHAPE = 1 << 13, # 6 bits, 128 shape gradient, 0 for cube 128 for sphere 255 for spike
#	RESERVED = 1 << 19, # 5 bits reserved
#	USERDATA = 1 << 24 # 48 bits for userdata
#}
#var voxels = []


@export var voxel_count = Vector3(8,8,8):
	set(nv):
		if nv.x == 0 or nv.y == 0 or nv.z == 0:
			push_error("VoxelData size cannot be zero: %s. -> Ignored" % nv)
			return
		
		#print("Setting VoxelData size to: %s" % nv)
		
		voxel_count = nv.floor() # round downwards
		real_size = voxel_count * voxel_scale
		total_count = voxel_count.x * voxel_count.y * voxel_count.z 
		smallest_count = min(min(voxel_count.x,voxel_count.y),voxel_count.z)
		largest_count = max(max(voxel_count.x,voxel_count.y),voxel_count.z)
		
		if calculation_state == CALC_STATE.INIT:
			calculation_state = CALC_STATE.NONE
		_change_state_to(CALC_STATE.INIT)
		_notify_state_change()

# scale in proportion to voxel_base_scale
@export var voxel_scale = 1:
	set(nv):
		voxel_scale = nv
		# recalculate size
		real_size = voxel_count * voxel_scale

var real_size = Vector3(8,8,8):
	set(nv):
		push_warning("'real_size' is read only. Use 'voxel_count' and 'voxel_scale' instead")

var total_count = 512:
	set(nv):
		push_warning("Can't set total. Read only")

var smallest_count = 8:
	set(nv):
		push_warning("Can't set smallest_count. Read only")

var largest_count = 8:
	set(nv):
		push_warning("Can't set largest_count. Read only.")


@export var material : PackedInt32Array = PackedInt32Array():
	set(nv):
		#print("_set_material")
		_change_state_to(CALC_STATE.VOXEL)
		
		_vox_m_mutex.lock()
		material = nv
		_vox_m_mutex.unlock()
		
		_notify_state_change()

@export var smooth : PackedByteArray = PackedByteArray():
	set(nv):
		#print("_set_smooth")
		_change_state_to(CALC_STATE.VOXEL)
		
		_vox_s_mutex.lock()
		smooth = nv
		_vox_s_mutex.unlock()
		
		_notify_state_change()

@export var visible : PackedByteArray = PackedByteArray():
	set(nv):
		#print("_set_visible")
		_change_state_to(CALC_STATE.VIS)
		
		_vox_v_mutex.lock()
		visible = nv
		_vox_v_mutex.unlock()
		
		_notify_state_change()

# Accumulation buffer used by PaintOperations
@export var blend_buffer : Array[float] = []:
	set(nv):
		_vox_b_mutex.lock()
		blend_buffer = nv
		_vox_b_mutex.unlock()

# Can´t use export -> will save mesh data to file
#export(Mesh) var mesh setget _set_mesh
var mesh:
	set(nv):
		#push_warning("Can't set mesh: Read only. Use replace_mesh(...) instead ")
		pass

var has_uv = false:
	set(nv):
		#push_warning("Can't set mesh: Read only. Use replace_mesh(...) instead ")
		pass

# used for changing only materials when mesh is already calculated
var material_table


enum CALC_STATE {
	NONE,
	INIT,
	VOXEL,
	VIS,
	MESH,
	UV
}

#can´t use export: exports are saved to file and set upon loading scene
#export(CALC_STATE) var calculation_state = CALC_STATE.NONE setget _set_calculation_state
var calculation_state : CALC_STATE = CALC_STATE.NONE:
	set(nv):
		#push_warning("Can't set mesh: Read only. Use replace_mesh(...) instead ")
		pass


var _vox_m_mutex = Mutex.new()
var _vox_s_mutex = Mutex.new()
var _vox_v_mutex = Mutex.new()
var _vox_b_mutex = Mutex.new()
var _mesh_mutex = Mutex.new()


func replace_mesh(new_mesh, new_has_uv = false):
	#print("_set_mesh")
	if not new_mesh:
		_change_state_to(CALC_STATE.MESH-1)
	
	if not new_has_uv:
		_change_state_to(CALC_STATE.MESH)
	else:
		_change_state_to(CALC_STATE.UV)
	
	_mesh_mutex.lock()
	mesh = new_mesh
	_mesh_mutex.unlock()
	
	_notify_state_change()


func set_state(new_state):
	_change_state_to(new_state)
	_notify_state_change()

# Clears all voxel data to zero
func clear():
	set_state(CALC_STATE.INIT)


func _init():
	calculation_state = CALC_STATE.NONE
	_change_state_to(CALC_STATE.INIT)



# Takes care that no leftover data is available and all variables are initialized properly
func _change_state_to(new_state):
	#print("VoxelData: change state to %s" % CALC_STATE.keys()[calculation_state])
	
	while new_state != calculation_state:
		# Raise or lower  one level at a time
		if new_state > calculation_state:
			calculation_state = calculation_state + 1
		elif new_state < calculation_state:
			calculation_state = calculation_state - 1
		
		match calculation_state:
		
			CALC_STATE.INIT:
				_vox_m_mutex.lock()
				_vox_s_mutex.lock()
				_vox_v_mutex.lock()
				_vox_b_mutex.lock()
				material = Array()
				smooth = Array()
				blend_buffer = Array()
				visible = null
				material.resize(total_count)
				smooth.resize(total_count)
				blend_buffer.resize(total_count)
				_vox_m_mutex.unlock()
				_vox_s_mutex.unlock()
				_vox_v_mutex.unlock()
				_vox_b_mutex.unlock()
			
			CALC_STATE.VOXEL:
				_vox_v_mutex.lock()
				visible = Array()
				visible.resize(total_count)
				_vox_v_mutex.unlock()
			
			CALC_STATE.VIS:
				_mesh_mutex.lock()
				mesh = null
				_mesh_mutex.unlock()
			
			CALC_STATE.MESH:
				has_uv = false
			
			CALC_STATE.UV:
				has_uv = true


func _notify_state_change():
	emit_signal("voxel_data_changed",calculation_state)
	notify_property_list_changed()
