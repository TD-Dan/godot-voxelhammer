@tool

extends Control

var _selection = null

var editor_interface = null

@onready var selected_info = $Panel/VBoxContainer/SelectedInfo
@onready var selected_info_more = $Panel/VBoxContainer/SelectedMoreInfo
@onready var selected_container = $Panel/VBoxContainer/SelectedScrollContainer

@onready var paint_stack_editor = $Panel/VBoxContainer/SelectedScrollContainer/VBoxContainer/PaintStackEditor

func set_selection(nv):
	print("VoxelHammerDock: setting selection")
	
	#TODO enable / make smarter
	
#	if nv is VoxelNode:
#		_selection = nv
#	elif nv is VoxelThing:
#		_selection = nv.voxel_body
#	elif nv is VoxelTerrainChunk:
#		_selection = nv.voxel_body
#	elif nv is VoxelTerrain:
#		_selection = nv
#	else:
#		_selection = null
#		selected_container.visible = false
#		selected_info.text = "Selection: none"
#		selected_info_more.text = " "
#		paint_stack_editor.paint_stack = null
#
#	if _selection:
#		selected_container.visible = true
#		paint_stack_editor.paint_stack = _selection.paint_stack
#		if _selection is VoxelNode:
#			selected_info.text = "Selection: VoxelNode %s" % _selection
#			var vox_count = 0
#			if _selection.voxel_data:
#				vox_count = _selection.voxel_data.total_count
#			selected_info_more.text = "Voxel count: %s \n" % vox_count
#		elif _selection is VoxelTerrain:
#			selected_info.text = "Selection: VoxelTerrain %s" % _selection
#			var vox_count = _selection.get_total_count()
#			selected_info_more.text = "Chunks: %s, Voxels: %s \n" % [_selection._chunks.size(), vox_count]
		


func _ready():
	selected_container.visible = false
	paint_stack_editor.connect("paint_stack_changed", _on_paint_stack_changed)
	paint_stack_editor.editor_interface = editor_interface


func _on_paint_stack_changed():
	print("VoxelHammerDock: paint stack changed")
	if _selection:
		_selection.paint_stack = paint_stack_editor.paint_stack


func _on_EditButton_pressed():
	if editor_interface and _selection.paint_stack:
		editor_interface.inspect_object(_selection.paint_stack)


func _on_RepaintButton_pressed():
	_selection.paint_stack = paint_stack_editor.paint_stack
	paint_stack_editor.populate_tree()


func _on_EditGlobalsButton_pressed():
	if editor_interface:
		var vh_autoload_global = get_node_or_null("/root/VoxelHammer")
		if vh_autoload_global:
			editor_interface.inspect_object(vh_autoload_global)
		else:
			push_warning("VoxalHammer Global Autoload NOT found. Did VoxelHammer Plugin load correctly?")
