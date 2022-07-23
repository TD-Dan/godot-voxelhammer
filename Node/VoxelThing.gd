tool

extends RigidBody

class_name VoxelThing

enum COL_TYPE {
	NONE,
	CUBE,
	CONVEX,
	CONCAVE
}

export(COL_TYPE) var collision_type = COL_TYPE.CUBE setget _set_col_type

var col_shape : CollisionShape

var voxel_body : VoxelNode

export var thing_data : Dictionary


func _set_col_type(nv):
	collision_type = nv
	create_collision_shape()


func _ready():
	#print("VoxelThing ready...")
	if not voxel_body:
		voxel_body = VoxelNode.new()
		#print("VoxelThing created voxel_body: %s" % voxel_body)
		add_child(voxel_body)
		
		voxel_body.voxel_data.voxel_count = Vector3(32,32,32)
		voxel_body.voxel_data.voxel_scale = voxel_body.configuration.voxel_base_size
		voxel_body.translation = - voxel_body.voxel_data.real_size/2
		
		voxel_body.do_fill = true
		thing_data["voxel_data"] = voxel_body.voxel_data
		
		voxel_body.voxel_data.connect("voxel_data_changed", self, "_on_voxel_data_changed")
		
		#create_collision_shape()
	#print("VoxelThing ready.")


func _on_voxel_data_changed(what):
	#print("VoxelThing: got signal voxel_data_changed %s" % what)
	match what:
		VoxelData.CALC_STATE.INIT:
			voxel_body.translation = - voxel_body.voxel_data.real_size/2
		VoxelData.CALC_STATE.MESH:
			create_collision_shape()
		VoxelData.CALC_STATE.UV:
			create_collision_shape()


func create_collision_shape():
	#print("VoxelThing: Creating collision shape: %s" % COL_TYPE.keys()[collision_type])
	if not col_shape:
		col_shape = CollisionShape.new()
		add_child(col_shape)
	match collision_type:
		COL_TYPE.NONE:
			col_shape.shape = null
		COL_TYPE.CUBE:
			col_shape.shape = BoxShape.new()
			col_shape.shape.extents = voxel_body.voxel_data.real_size/2
