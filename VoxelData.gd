tool

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


export var voxel_count = Vector3(8,8,8) setget _set_voxel_count
# scale in proportion to voxel_base_scale
export var voxel_scale = 1 setget _set_voxel_scale

var real_size = Vector3(8,8,8) setget _set_real_size
var total_count = 512 setget _set_total
var smallest_count = 8 setget _set_smallest_count
var largest_count = 8 setget _set_largest_count


export(PoolIntArray) var material = PoolIntArray() setget _set_material
export(PoolByteArray) var smooth = PoolByteArray() setget _set_smooth
export(PoolByteArray) var visible = PoolByteArray() setget _set_visible

# Accumulation buffer used by PaintOperations
export(Array, float) var blend_buffer = [] setget _set_blend_buffer

# Can´t use export -> will save mesh data to file
#export(Mesh) var mesh setget _set_mesh
var mesh setget _set_mesh

var has_uv = false setget _set_has_uv

# used for changing only materials later on
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
var calculation_state = CALC_STATE.NONE setget _set_calculation_state


var _vox_m_mutex = Mutex.new()
var _vox_s_mutex = Mutex.new()
var _vox_v_mutex = Mutex.new()
var _vox_b_mutex = Mutex.new()
var _mesh_mutex = Mutex.new()


func _set_voxel_count(nv):
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

func _set_voxel_scale(nv):
	voxel_scale = nv
	# recalculate size
	real_size = voxel_count * voxel_scale


func _set_real_size(nv):
	push_warning("'real_size' is read only. Use 'voxel_count' and 'voxel_scale' instead")

func _set_total(nv):
	push_warning("Can't set total. Read only")

func _set_smallest_count(nv):
	push_warning("Can't set smallest_count. Read only")

func _set_largest_count(nv):
	push_warning("Can't set largest_count. Read only.")


func _set_material(nv):
	#print("_set_material")
	_change_state_to(CALC_STATE.VOXEL)
	
	_vox_m_mutex.lock()
	material = nv
	_vox_m_mutex.unlock()
	
	_notify_state_change()

func _set_smooth(nv):
	#print("_set_smooth")
	_change_state_to(CALC_STATE.VOXEL)
	
	_vox_s_mutex.lock()
	smooth = nv
	_vox_s_mutex.unlock()
	
	_notify_state_change()

func _set_blend_buffer(nv):	
	_vox_b_mutex.lock()
	blend_buffer = nv
	_vox_b_mutex.unlock()

func _set_visible(nv):
	#print("_set_visible")
	_change_state_to(CALC_STATE.VIS)
	
	_vox_v_mutex.lock()
	visible = nv
	_vox_v_mutex.unlock()
	
	_notify_state_change()

func _set_mesh(nv):
	#push_warning("Can't set mesh: Read only. Use replace_mesh(...) instead ")
	pass

func _set_has_uv(nv):
	#push_warning("Can't set mesh: Read only. Use replace_mesh(...) instead ")
	pass

func _set_calculation_state(nv):
	#push_warning("Can't set mesh: Read only. Use replace_mesh(...) instead ")
	pass


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
	property_list_changed_notify()


