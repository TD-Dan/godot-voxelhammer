@tool

extends Control



var editor_interface : EditorInterface

@onready var selected_info = $Panel/VBoxContainer/SelectedInfo
@onready var selected_info_more = $Panel/VBoxContainer/SelectedMoreInfo

@onready var voxel_edit_tools = $Panel/VBoxContainer/VoxelEditTools
@onready var paint_stack_tools = $Panel/VBoxContainer/PaintStackTools
@onready var voxel_edit_material = $Panel/VBoxContainer/VoxelEditTools/SpinBoxMaterial
@onready var paint_stack_editor = $Panel/VBoxContainer/PaintStackTools/VBoxContainer/PaintStackEditor

@onready var button_paint = $Panel/VBoxContainer/VoxelEditTools/ButtonPaint
var mousemode_paint = false

@onready var paint_marker_scene = preload("../../res/paint_marker.tscn")
var paint_marker : Node3D

var selection = null:
	set(nv):
		#print("VoxelHammerDock: setting selection")
		
		#TODO enable / make smarter
		
		button_paint.button_pressed = false
		
		if nv is VoxelBody3D:
			var child = nv.get_node_or_null("VoxelInstance")
			if child:
				nv = child
			
		elif nv is VoxelInstance:
			selection = nv
			
			if not selection.data_changed.is_connected(_on_selection_data_changed):
				selection.data_changed.connect(_on_selection_data_changed)
				
			voxel_edit_tools.visible = true
			selected_info.text = "Selection: %s" % selection
			var vox_count = 0
			if selection.voxel_data:
				vox_count = selection.voxel_data.get_voxel_count()
			selected_info_more.text = "Voxel count: %s \n" % vox_count
			paint_stack_editor.paint_stack = selection.paint_stack
	#	elif nv is VoxelThing:
	#		_selection = nv.voxel_body
	#	elif nv is VoxelTerrainChunk:
	#		_selection = nv.voxel_body
	#	elif nv is VoxelTerrain:
	#		_selection = nv
	
		elif nv is VoxelTerrain:
			selection = nv
		
		else:
			selection = null
			voxel_edit_tools.visible = false
			paint_stack_editor.paint_stack = null
		
		_update_selected_info_text()

func _on_selection_data_changed(what):
	#print("detected change in selected data: %s !" % str(what))
	_update_selected_info_text()

func _update_selected_info_text():
	if selection:
		selected_info.text = "Selection: %s" % selection
		if "voxel_data" in selection and selection.voxel_data:
			var vox_count = selection.voxel_data.get_voxel_count()
			selected_info_more.text = "Voxels: %s" % vox_count
		if "visibility_count" in selection:
			selected_info_more.text += ", Visible: %s" % selection.visibility_count
		if "mesh_surfaces_count" in selection:
			selected_info_more.text += ", Surfaces-Faces: %s-%s" % [selection.mesh_surfaces_count, selection.mesh_faces_count]
		
		if "voxel_chunks" in selection:
			selected_info_more.text = "Chunks: %s, Voxels: %s" % [selection.voxel_chunks.size(), selection.get_total_voxels()]
		
	else:
		selected_info.text = "Selection: none"
		selected_info_more.text = "Select a VoxelHammer node in editor to edit here"


func _ready():
	paint_stack_editor.connect("paint_stack_changed", _on_paint_stack_changed)
	paint_stack_editor.editor_interface = editor_interface


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent):
	#if event.get_class() != "InputEventMouseMotion":
		#print("got input %s" % event.get_class())
	
	if mousemode_paint:
		match event.get_class():
			"InputEventKey":
				if Input.is_action_pressed("ui_cancel"):
					button_paint.button_pressed = false
					return true
			"InputEventMouseButton":
				var event_mb : InputEventMouseButton = event

				# Need to manually pick in tool mode and VoxelInstance picking logic not running

				if selection and event_mb.button_index == 1 and event_mb.is_pressed():
					#print("%s: got input %s" % [self,str(event)])
					var mouse_pos = event.position
					var camera = viewport_camera
					
					var ray_length = 100.0
					var from = camera.project_ray_origin(mouse_pos)
					var to = from + camera.project_ray_normal(mouse_pos) * ray_length
					var space_state = selection.get_viewport().find_world_3d().get_direct_space_state()
					var params = PhysicsRayQueryParameters3D.new()
					params.from = from
					params.to = to
					var results =  space_state.intersect_ray(params)
					#print(results)
					if results.size() > 0:
						var pos : Vector3 = selection.to_local(results["position"])
						var norm = results["normal"]
						#print(norm)
						#print(pos.floor())
						var mat = voxel_edit_material.value
						
						if mat == 0:
							pos = (pos - norm/2).floor()
						else:
							pos = (pos + norm/2).floor()
						
						if paint_marker:
							paint_marker.global_position = selection.to_global(pos)
						else:
							push_error("Can't find paint_marker node. Has somebody deleted it?")
						
						selection.set_voxel(pos, mat)
						selection.remesh()
					return true
	return false


func _on_paint_stack_changed():
	print("VoxelHammerDock: paint stack changed")
	if selection:
		selection.paint_stack = paint_stack_editor.paint_stack


func _on_EditButton_pressed():
	if editor_interface and selection.paint_stack:
		editor_interface.inspect_object(selection.paint_stack)


func _on_RepaintButton_pressed():
	selection.paint_stack = paint_stack_editor.paint_stack
	paint_stack_editor.populate_tree()


func _on_EditGlobalsButton_pressed():
	if editor_interface:
		var vh_autoload_global = get_node_or_null("/root/VoxelHammer")
		if vh_autoload_global:
			editor_interface.inspect_object(vh_autoload_global)
		else:
			push_warning("VoxalHammer Global Autoload NOT found. Did VoxelHammer Plugin load correctly?")


func _on_button_clear_pressed():
	selection.voxel_data.clear()


func _on_button_fill_pressed():
	var mat = voxel_edit_material.value
	selection.push_voxel_operation(VoxelOpFill.new(mat))


func _on_button_paint_toggled(button_pressed):
	mousemode_paint = button_pressed
	
	var scene_root = editor_interface.get_edited_scene_root()
	if paint_marker:
			scene_root.remove_child(paint_marker)
			paint_marker.queue_free()
			paint_marker = null
			#paint_marker.owner = null
	
	var failed_to_enter_mode = false
	if mousemode_paint:
		if selection.mesh_scale != 1.0:
			push_warning("Paint mode not supported for scaled meshes. This is a Godot limitation. Use 'Mesh Scale' 1.0 to enable live paint.")
			failed_to_enter_mode = true
		elif selection.generate_collision_sibling != VoxelInstance.COLLISION_MODE.CONCAVE_MESH:
			push_warning("Paint mode supported only when a concave mesh is present. Set 'Generate Collision Sibling' to 'Concave Mesh' to enable live paint.")
			failed_to_enter_mode = true
		
	if failed_to_enter_mode:
		mousemode_paint = false
		button_paint.button_pressed = false
		return
	
	if mousemode_paint:
		paint_marker = paint_marker_scene.instantiate()
		scene_root.add_child(paint_marker)
		#paint_marker.owner = scene_root


func _on_button_mesh_pressed():
	selection.remesh()


func _on_add_vox_instance_pressed():
	button_paint.button_pressed = false
	# TODO: Add UndoRedo
	# Get current selection
	var scene_root = editor_interface.get_edited_scene_root()
	var new_owner =  editor_interface.get_edited_scene_root()
	
	var new_parent = scene_root
	var sel = editor_interface.get_selection().get_selected_nodes()
	if not sel.is_empty():
		new_parent = sel[0]
	
	if new_parent:
		var new_vox = VoxelInstance.new()
		new_vox.name = "VoxelInstance"
		new_parent.add_child(new_vox,true)
		new_vox.owner = new_owner


func _on_add_vox_body_pressed():
	button_paint.button_pressed = false
	# TODO: Add UndoRedo
	# Get current selection
	var scene_root = editor_interface.get_edited_scene_root()
	var new_owner =  editor_interface.get_edited_scene_root()
	
	var new_parent = scene_root
	var sel = editor_interface.get_selection().get_selected_nodes()
	if not sel.is_empty():
		new_parent = sel[0]
	
	if new_parent:
		var new_vox = VoxelBody3D.new()
		new_vox.name = "VoxelBody3D"
		new_parent.add_child(new_vox,true)
		new_vox.owner = new_owner
