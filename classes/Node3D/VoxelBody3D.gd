@tool

extends StaticBody3D

class_name VoxelBody3D

@export var paint_mode : bool = false
@export var paint_mat : int = 2

@onready var voxel_instance : VoxelInstance3D = $VoxelInstance3D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.is_pressed():
		if paint_mode:
			print("Got "+str(event)+ " " + str(position) + " " + str(normal))
			var pos : Vector3 = to_local(position)
			var norm = (transform * normal).normalize()
			var mat = -1
			
			if event.button_index == 1:
				pos = (pos + norm/2).floor()
				mat = paint_mat
			elif event.button_index == 3:
				pos = (pos - norm/2).floor()
				mat = 0
			
			print("Localised position: " + str(pos) + ", normal:" + str(norm))
			
			if mat >= 0:
				print("setting")
				voxel_instance.set_voxel(pos, mat)
