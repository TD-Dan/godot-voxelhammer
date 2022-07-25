@tool

extends Resource

class_name VoxelData

#
## Voxel data storage resource
#


signal voxel_data_changed(what)

@export var voxel_count = Vector3i(8,8,8):
	set(nv):
		if nv.x == 0 or nv.y == 0 or nv.z == 0:
			push_error("VoxelData size cannot be zero: %s. -> Ignored" % nv)
			return
		
		voxel_count = nv
		
		print("Setting VoxelData size to: %s" % nv)
		
		voxel_count = nv.floor() # round downwards
		real_size = voxel_count * voxel_scale
		total_count = voxel_count.x * voxel_count.y * voxel_count.z 
		smallest_count = min(min(voxel_count.x,voxel_count.y),voxel_count.z)
		largest_count = max(max(voxel_count.x,voxel_count.y),voxel_count.z)
		
		if calculation_state == CALC_STATE.INIT:
			calculation_state = CALC_STATE.NONE
		_change_state_to(CALC_STATE.INIT)
		_notify_state_change()


@export var voxel_scale = 1.0

var real_size = Vector3(8,8,8)
var total_count = 512
var smallest_count = 8
var largest_count = 8

@export var material : PackedInt32Array = PackedInt32Array():
	set(nv):
		_change_state_to(CALC_STATE.VOXEL)
		
		_vox_m_mutex.lock()
		material = nv
		_vox_m_mutex.unlock()
		
		_notify_state_change()
@export var smooth : PackedByteArray = PackedByteArray():
	set(nv):
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

@export var blend_buffer : PackedFloat32Array = PackedFloat32Array():
	set(nv):
		_vox_b_mutex.lock()
		blend_buffer = nv
		_vox_b_mutex.unlock()

# Can´t use export -> will save mesh data to file
#export(Mesh) var mesh setget _set_mesh
var mesh : Mesh = null

var has_uv = false

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
var calculation_state = CALC_STATE.NONE


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
				material = PackedInt32Array()
				smooth = PackedByteArray()
				blend_buffer = PackedFloat32Array()
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
				visible = PackedByteArray()
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
