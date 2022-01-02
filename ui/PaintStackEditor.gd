tool

extends Panel

signal paint_stack_changed


var editor_interface = null

var voxel_node = null

onready var remove_icon = preload("res://addons/voxel_hammer/ui/icons/Close.svg")
onready var edit_icon = preload("res://addons/voxel_hammer/ui/icons/Edit.svg")
onready var hidden_icon = preload("res://addons/voxel_hammer/ui/icons/GuiVisibilityHidden.svg")
onready var visible_icon = preload("res://addons/voxel_hammer/ui/icons/GuiVisibilityVisible.svg")
onready var up_icon = preload("res://addons/voxel_hammer/ui/icons/MoveUp.svg")
onready var down_icon = preload("res://addons/voxel_hammer/ui/icons/MoveDown.svg")

onready var add_button = $VBoxContainer/AddButton
onready var tree = $VBoxContainer/Tree
var tree_root

var paint_stack = null setget _set_paint_stack


func _set_paint_stack(nv):
	#print("PaintStackEditor: setting paint stack")
	if paint_stack:
		if paint_stack.is_connected("operation_stack_changed", self, "_on_paint_stack_changed"):
			paint_stack.disconnect("operation_stack_changed", self, "_on_paint_stack_changed")
	
	paint_stack = nv
	
	if paint_stack:
		paint_stack.connect("operation_stack_changed", self, "_on_paint_stack_changed")
	
	populate_tree()


func _on_paint_stack_changed():
	#print("PaintStackEditor: Paint operation stack changed")
	populate_tree()
	

func _init(voxel_node = null):
	self.voxel_node = voxel_node


func _ready():
	tree.set_column_min_width(0,60)
	tree.set_column_min_width(1,7)
	tree.set_column_min_width(2,7)
	tree.set_column_min_width(3,7)
	tree.set_column_min_width(4,7)
	tree.set_column_min_width(5,7)
	
	tree_root = tree.create_item()
	
	var add_popup = add_button.get_popup()
	add_popup.connect("index_pressed",self,"_on_add_popup_selection")


func populate_tree():
	#print("PaintStackEditor: populating tree")
	if not paint_stack:
		if tree:
			tree.clear()
			tree_root = tree.create_item()
	else:
		tree.clear()
		tree_root = tree.create_item()
		var i = 0
		for paint_op in paint_stack.operation_stack:
			var item = tree.create_item(tree_root)
			set_item_data(item, paint_op, i)
			i += 1


func commit_tree():
	#print("PaintStackEditor: commit tree")
	emit_signal("paint_stack_changed")


func set_item_data(item, paint_op, index):
	#print("PaintStackEditor: index = %s" % index)
	var mode = "N"
	match paint_op.paint_mode:
		VoxelPaintStack.PAINT_MODE.REPLACE:
			mode = "R"
		VoxelPaintStack.PAINT_MODE.ADD:
			mode = "A"
		VoxelPaintStack.PAINT_MODE.ERASE:
			mode = "E"
		VoxelPaintStack.PAINT_MODE.NONE:
			mode = "-"
	
	var smooth = "n"
	if paint_op.smooth:
		smooth = "y"
	
	var opname = "unimplemented"
	var spec_info = ""
	if paint_op is PaintOpPlane:
		opname = "Plane"
		spec_info = "%s, %s " % [paint_op.low, paint_op.high]
	if paint_op is PaintOpGradient:
		opname = "Gradient"
		spec_info = "%s, %s " % [paint_op.offset, paint_op.distance]
	if paint_op is PaintOpGradientVector:
		opname = "GradientVector"
		spec_info = "%s, %s " % [paint_op.offset, paint_op.distance]
	if paint_op is PaintOpSimplexNoise:
		opname = "Simplex Noise"
		spec_info = "%s, %s, %s, %s " % [paint_op.lucanarity, paint_op.octaves, paint_op.period, paint_op.persistence]
	
	item.set_text(0, "%s (%s, %s, %s ) (%s)" % [opname, mode, paint_op.material, smooth, spec_info])
	
	
	item.add_button(1, edit_icon)
	item.add_button(2, visible_icon)
	if not paint_op.active: 
		item.set_button(2,0, hidden_icon)
	item.add_button(3, up_icon)
	item.add_button(4, down_icon)
	item.add_button(5, remove_icon)
	
	item.set_metadata(0, paint_op)
	item.set_metadata(1, index)
	
	
func _on_add_popup_selection(index):
	#print("selection: %s" % index)
	
	var item = tree.create_item(tree_root)
	item.set_text(0, "Unimplemented")
	
	if not paint_stack:
		paint_stack = VoxelPaintStack.new()
		emit_signal("paint_stack_changed")
	
	var paint_op = null
	
	match index:
		0: # Plane
			paint_op = PaintOpPlane.new(VoxelPaintStack.PAINT_MODE.NORMAL, 1, true, 0, 1)
		1: # Gradient
			paint_op = PaintOpGradient.new(VoxelPaintStack.PAINT_MODE.NORMAL, 1, true, 0, 10)
		2: # GradientVector
			paint_op = PaintOpGradientVector.new(VoxelPaintStack.PAINT_MODE.NORMAL, 1, true, 0, 10)
		3: # Simplex noise
			paint_op = PaintOpSimplexNoise.new(VoxelPaintStack.PAINT_MODE.NORMAL, 1, true)
	
	if paint_op:
		paint_stack.add_paint_operation(paint_op)
		set_item_data(item, paint_op, paint_stack.get_op_count())
	
	commit_tree()


func _on_Tree_button_pressed(item, column, id):
	#print("Tree: button pressed")
	var paint_op : PaintOperation = item.get_metadata(0)
	var index = item.get_metadata(1)
	if column == 1 and Engine.is_editor_hint() and editor_interface: # edit in inspector
		editor_interface.inspect_object(paint_op)
	elif column == 2: # hide / unhide
		paint_op.active = not paint_op.active
		if paint_op.active: 
			item.set_button(2,0, visible_icon)
		else:
			item.set_button(2,0, hidden_icon)
		property_list_changed_notify()
	elif column == 3: # move up
		paint_stack.move_paint_operation(paint_op,index-1)
		populate_tree()
	elif column == 4: # move down
		paint_stack.move_paint_operation(paint_op,index+1)
		populate_tree()
	elif column == 5: # remove
		paint_stack.remove_paint_operation(paint_op)
		item.free()

