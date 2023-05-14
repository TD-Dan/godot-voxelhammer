@tool

extends Node3D

class_name DebugMesh

@export var size : Vector3 = Vector3(1,1,1):
	set(nv):
		size = nv
		_update_debug_mesh()



@export var color : Color = Color(0,0,0):
	set(nv):
		color = nv
		_update_debug_mesh()


@export_multiline var text : String = "":
	set(nv):
		text = nv
		_update_debug_mesh()


# Debug linemesh that shows current mesh calculation status and size
var _debug_mesh_child : MeshInstance3D = null

var _debug_label_child : Label3D = null


func _init(color = Color(1,1,1)):
	self.color = color


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_debug_mesh()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _update_debug_mesh():
	#print("Creating debug mesh...")
	if not _debug_mesh_child:
		_debug_mesh_child = MeshInstance3D.new()
		add_child(_debug_mesh_child)
	
	if text:
		if not _debug_label_child:
			_debug_label_child = Label3D.new()
			_debug_label_child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_debug_label_child.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			#_debug_label_child.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			_debug_label_child.pixel_size = 0.001
			add_child(_debug_label_child)
		_debug_label_child.position.y = size.y
		_debug_label_child.text = text
	
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(color)
	
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
	_debug_mesh_child.mesh.surface_set_material(0, load(VoxelHammer.plugin_directory+"res/line.tres"))
