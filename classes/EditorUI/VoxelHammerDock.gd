@tool

extends Control



var editor_interface = null

@onready var selected_info = $Panel/VBoxContainer/SelectedInfo
@onready var selected_info_more = $Panel/VBoxContainer/SelectedMoreInfo
@onready var selected_container = $Panel/VBoxContainer/SelectedScrollContainer

@onready var voxel_edit_tools = $Panel/VBoxContainer/VoxelEditTools
@onready var voxel_edit_material = $Panel/VBoxContainer/VoxelEditTools/SpinBoxMaterial
@onready var paint_stack_editor = $Panel/VBoxContainer/SelectedScrollContainer/VBoxContainer/PaintStackEditor

var selection = null:
	set(nv):
		#print("VoxelHammerDock: setting selection")
		if selection and selection.is_connected("data_changed", _on_selection_data_changed):
			selection.disconnect("data_changed", _on_selection_data_changed)
		
		#TODO enable / make smarter
		
		if nv is VoxelInstance3D:
			selection = nv
			
			if not selection.is_connected("data_changed", _on_selection_data_changed):
				selection.connect("data_changed", _on_selection_data_changed)
				
			voxel_edit_tools.visible = true
			selected_container.visible = true
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
		else:
			selection = null
			voxel_edit_tools.visible = false
			selected_container.visible = false
			paint_stack_editor.paint_stack = null
		
		_update_selected_info_text()

func _on_selection_data_changed(what):
	#print("detected change in selected data: %s !" % str(what))
	_update_selected_info_text()

func _update_selected_info_text():
	if selection:
		selected_info.text = "Selection: %s" % selection
		var vox_count = 0
		if selection.voxel_data:
			vox_count = selection.voxel_data.get_voxel_count()
		selected_info_more.text = "Voxel count: %s" % vox_count
		if selection.visibility_count != null:
			selected_info_more.text += ", Visible: %s" % selection.visibility_count
			
		if selection.mesh_surfaces_count != null:
			selected_info_more.text += ", Surfaces-Faces: %s-%s" % [selection.mesh_surfaces_count, selection.mesh_faces_count]
	
	else:
		selected_info.text = "Selection: none"
		selected_info_more.text = "Select a VoxelHammer node in editor to edit here"


func _ready():
	selected_container.visible = false
	# TODO: enable
	#paint_stack_editor.connect("paint_stack_changed", _on_paint_stack_changed)
	paint_stack_editor.editor_interface = editor_interface


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
	pass # Replace with function body.


func _on_button_mesh_pressed():
	selection.push_voxel_operation(VoxelOpVisibility.new())
