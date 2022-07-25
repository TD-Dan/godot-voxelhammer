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
		
		#TODO enable / make smarter
		
		if nv is VoxelInstance3D:
			selection = nv
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
		elif nv:
			selection = null
			voxel_edit_tools.visible = false
			selected_container.visible = false
			selected_info.text = "Selection: %s" % nv
			selected_info_more.text = "Select a VoxelHammer node in editor to edit here"
			paint_stack_editor.paint_stack = null
		else:
			selection = null
			voxel_edit_tools.visible = false
			selected_container.visible = false
			selected_info.text = "Selection: none"
			selected_info_more.text = "Select a VoxelHammer node in editor to edit here"
			paint_stack_editor.paint_stack = null



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
	var sel : VoxelInstance3D = selection
	sel.voxel_data.clear()
	sel.notify_property_list_changed()


func _on_button_fill_pressed():
	var mat = voxel_edit_material.value
	var sel : VoxelInstance3D = selection
	sel.push_voxel_operation(VoxelOpFill.new(sel, mat))


func _on_button_paint_toggled(button_pressed):
	pass # Replace with function body.
