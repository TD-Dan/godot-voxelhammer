@tool

extends EditorPlugin

var eds

var dock

func _enter_tree():
	print("VoxelHammer plugin loading...")
	add_custom_type("VoxelConfiguration", "Resource", preload("VoxelConfiguration.gd"), preload("icon_vh.png"))
	add_custom_type("VoxelPaintStack", "Resource", preload("VoxelPaintStack.gd"), preload("icon_vh.png"))
	add_custom_type("VoxelNode", "Spatial", preload("VoxelNode.gd"), preload("icon_vh.png"))
	add_custom_type("VoxelTerrain", "Spatial", preload("VoxelTerrain.gd"), preload("icon_vh.png"))
	add_custom_type("VoxelThing", "RigidBody", preload("VoxelThing.gd"), preload("icon_vh.png"))
	name = "VoxelHammerPlugin"
	
	eds = get_editor_interface().get_selection()
	
	eds.connect("selection_changed", self, "_on_selection_changed")
	
	var dock_vh = preload("res://addons/voxel_hammer/ui/VoxelHammerDock.tscn")
	dock_vh.resource_local_to_scene = true
	dock = dock_vh.instance()
	dock.editor_interface = get_editor_interface()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	
	add_autoload_singleton("VoxelHammer", "res://addons/voxel_hammer/VoxelHammer.gd")


func _exit_tree():
	print("VoxelHammer plugin unloading...")
	remove_custom_type("VoxelConfiguration")
	remove_custom_type("VoxelPaintStack")
	remove_custom_type("VoxelNode")
	remove_custom_type("VoxelTerrain")
	remove_custom_type("VoxelThing")

	if dock:
		remove_control_from_docks(dock)
		dock.free()
	
	remove_autoload_singleton("VoxelHammer")


func _on_selection_changed():
	#print("VoxelHammerPlugin: selection changed")
	# Returns an array of selected nodes
	var selected = eds.get_selected_nodes() 
	
	if not selected.empty():
		# Always pick first node in selection
		if dock:
			var selected_node = selected[0]
			dock.set_selection(selected_node)
	else:
		if dock:
			dock.set_selection(null)
