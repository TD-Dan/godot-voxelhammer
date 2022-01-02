extends VoxelOperation

class_name VoxelOpPaintStack

var mat_buffer
var smooth_buffer
var blend_buffer
var paint_stack
var position_offset

func _init(voxel_data, voxel_configuration, paint_stack, position_offset=Vector3(0,0,0)).(VoxelData.CALC_STATE.VOXEL, voxel_data, voxel_configuration): 
	self.metadata.name = "VoxelOpPaintStack"
	self.paint_stack = paint_stack.duplicate()
	self.position_offset = position_offset


func to_string ():
	return "[VoxelOpPaintStack]"


# Runs in main node to prepare data
func prepare():
	mat_buffer = voxel_data.material.duplicate()
	smooth_buffer = voxel_data.smooth.duplicate()
	blend_buffer = voxel_data.blend_buffer.duplicate()


# This code is executed in another thread so it can not access voxel_node variable!
func execute(thread_cache : Dictionary):
	#print("!!! VoxelOpVisibility executing!")
	do_paint_stack()


# This code will be executed in the main thread so access to voxel_node is ok
func finalize():
	if !mat_buffer or !smooth_buffer:
		push_error("mat_buffer or smooth_buffer missing!")
	voxel_data.material = mat_buffer
	voxel_data.smooth = smooth_buffer
	voxel_data.blend_buffer = blend_buffer


# This code is executed in another thread so it can not access voxel_node variable!
func do_paint_stack():
	#print("Applying Voxel Paint stack...")
	
	var sx :int = voxel_data.voxel_count.x
	var sy :int = voxel_data.voxel_count.y
	var sz :int = voxel_data.voxel_count.z
	
	for op in paint_stack.operation_stack:
		if op.active:
			for z in range(sz):
				for y in range(sy):
					for x in range(sx):
						
						if cancel:
							return
						
						var cull_test = false
						var blend_change = 0.0
						
						if op is PaintOpPlane:
							var plane = x
							var offset = position_offset.x
							match op.plane:
								VoxelPaintStack.AXIS_PLANE.Y:
									plane = y
									offset = position_offset.y
								VoxelPaintStack.AXIS_PLANE.Z:
									plane = z
									offset = position_offset.z
									
							if plane >= op.low - offset and plane <= op.high - offset:
								cull_test = true
								blend_change = 1.0
						
						if op is PaintOpGradient:
							
							cull_test = true
							
							var point = x + position_offset.x
							match op.plane:
								VoxelPaintStack.AXIS_PLANE.Y:
									point = y + position_offset.y
								VoxelPaintStack.AXIS_PLANE.Z:
									point = z + position_offset.z
							
							var blend_amount = (op.offset - point) / op.distance
							
							if op.mirror:
								blend_amount = 1 - clamp(abs(blend_amount), 0, 1.0)
							else:
								blend_amount = clamp(blend_amount, 0, 1.0)
							
							if op.reverse:
								blend_amount = 1 - blend_amount
								
							blend_change = blend_amount
							
						if op is PaintOpGradientVector:
							cull_test=true
							
							var plane = op.plane
							var point = (Vector3(x,y,z) + position_offset) / op.distance
							var dot = plane.dot(point)
							
							if dot > 1.0:
								dot = 1.0
							if dot < 0:
								if op.mirror:
									dot = abs(dot)
								else:
									dot = 0
							
							dot = 1 - dot
							blend_change = dot
						
						if op is PaintOpSimplexNoise:
							cull_test = true
							blend_change = (op.noise.get_noise_3d(x+position_offset.x, y+position_offset.y, z+position_offset.z) + 1.0)
						
						
						if cull_test:
							blend_change *= op.blend_amount
							
							match op.blend_mode:
								VoxelPaintStack.BLEND_MODE.NORMAL:
									blend_buffer[x + y*sx + z*sx*sy] = blend_change
								VoxelPaintStack.BLEND_MODE.ADD:
									if not blend_buffer[x + y*sx + z*sx*sy]:
										blend_buffer[x + y*sx + z*sx*sy] = blend_change
									else:
										blend_buffer[x + y*sx + z*sx*sy] += blend_change
								VoxelPaintStack.BLEND_MODE.MINUS:
									if not blend_buffer[x + y*sx + z*sx*sy]:
										blend_buffer[x + y*sx + z*sx*sy] = -blend_change
									else:
										blend_buffer[x + y*sx + z*sx*sy] -= blend_change
								VoxelPaintStack.BLEND_MODE.ONE_MINUS:
									blend_buffer[x + y*sx + z*sx*sy] = 1 - blend_change
								VoxelPaintStack.BLEND_MODE.MULTIPLY:
									if blend_buffer[x + y*sx + z*sx*sy]:
										blend_buffer[x + y*sx + z*sx*sy] *= blend_change
								VoxelPaintStack.BLEND_MODE.NONE:
									pass
								
							if blend_buffer[x + y*sx + z*sx*sy] and blend_buffer[x + y*sx + z*sx*sy] >= 1:
								match op.paint_mode:
									VoxelPaintStack.PAINT_MODE.NORMAL:
										mat_buffer[x + y*sx + z*sx*sy] = op.material
										smooth_buffer[x + y*sx + z*sx*sy] = op.smooth
									VoxelPaintStack.PAINT_MODE.REPLACE:
										if mat_buffer[x + y*sx + z*sx*sy]:
											mat_buffer[x + y*sx + z*sx*sy] = op.material
											smooth_buffer[x + y*sx + z*sx*sy] = op.smooth
									VoxelPaintStack.PAINT_MODE.ADD:
										if not mat_buffer[x + y*sx + z*sx*sy]:
											mat_buffer[x + y*sx + z*sx*sy] = op.material
											smooth_buffer[x + y*sx + z*sx*sy] = op.smooth
									VoxelPaintStack.PAINT_MODE.ERASE:
										if mat_buffer[x + y*sx + z*sx*sy]:
											mat_buffer[x + y*sx + z*sx*sy] = 0
									VoxelPaintStack.PAINT_MODE.NONE:
										pass

