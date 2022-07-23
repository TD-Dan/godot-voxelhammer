@tool

extends EditorPlugin

var ed_sel

var dock

func _enter_tree():
	print("VoxelHammer plugin loading...")
	add_custom_type("VoxelConfiguration", "Resource", preload("VoxelConfiguration.gd"), preload("icon_vh.png"))
	add_custom_type("VoxelData", "Resource", preload("VoxelData.gd"), preload("icon_vh.png"))
	add_custom_type("VoxelInstance3D", "Node", preload("Node/VoxelInstance3D.gd"), preload("icon_vh.png"))
	#add_custom_type("VoxelNode", "Spatial", preload("VoxelNode.gd"), preload("icon_vh.png"))
	#add_custom_type("VoxelTerrain", "Spatial", preload("VoxelTerrain.gd"), preload("icon_vh.png"))
	#add_custom_type("VoxelThing", "RigidBody", preload("VoxelThing.gd"), preload("icon_vh.png"))
	name = "VoxelHammerPlugin"
	
	ed_sel = get_editor_interface().get_selection()
	ed_sel.connect("selection_changed", _on_selection_changed)
	
	var dock_vh = preload("res://addons/TallDwarf/VoxelHammer/ui/VoxelHammerDock.tscn")
	dock_vh.resource_local_to_scene = true
	dock = dock_vh.instantiate()
	dock.editor_interface = get_editor_interface()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	
	add_autoload_singleton("VoxelHammer", "res://addons/TallDwarf/VoxelHammer/VoxelHammer.gd")


func _exit_tree():
	print("VoxelHammer plugin unloading...")
	remove_custom_type("VoxelConfiguration")
	remove_custom_type("VoxelData")
	remove_custom_type("VoxelInstance3D")
	#remove_custom_type("VoxelPaintStack")
	#remove_custom_type("VoxelTerrain")
	#remove_custom_type("VoxelThing")

	if dock:
		remove_control_from_docks(dock)
		dock.free()
	
	remove_autoload_singleton("VoxelHammer")


func _on_selection_changed():
	print("VoxelHammerPlugin: selection changed")
	
	# Returns an array of selected nodes
	var selected : Array[Node] = ed_sel.get_selected_nodes() 
	
	if not selected.is_empty():
		# Always pick first node in selection
		if dock:
			var selected_node = selected[0]
			print("setting sel")
			dock.selection = selected_node
	else:
		if dock:
			dock.selection = null
