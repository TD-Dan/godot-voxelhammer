extends VoxelOperation

class_name VoxelOpPaintStack

var paint_stack
var position_offset


var blend_buffer : PackedFloat32Array = PackedFloat32Array()

func _init(paint_stack : VoxelPaintStack, position_offset=Vector3(0,0,0)):
	super("VoxelOpPaintStack", VoxelOperation.CALCULATION_LEVEL.VOXEL+20)
	self.paint_stack = paint_stack
	self.position_offset = position_offset


# This code is potentially executed in another thread!
func run_operation():
	#print("!!! VoxelOpPaintStack executing!")
	if voxel_instance.voxel_data.data_mutex.try_lock():
		do_paint_stack(voxel_instance.voxel_data.data, voxel_instance.voxel_data.size, paint_stack, position_offset)
		
		voxel_instance.voxel_data.data_mutex.unlock()
		voxel_instance.voxel_data.call_deferred("notify_data_changed")
	else:
		push_warning("VoxelOpFill: Can't get lock on voxel data!")


# This code is executed in another thread so it can not access voxel_node variable!
func do_paint_stack(data : PackedInt64Array, size : Vector3i, paint_stack : VoxelPaintStack, position_offset : Vector3):
	print("Applying Voxel Paint stack...")
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	blend_buffer.resize(data.size())
	
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
						
						if op is PaintOpNoise:
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
										data[x + y*sx + z*sx*sy] = op.material
									VoxelPaintStack.PAINT_MODE.REPLACE: # draw only if voxel already exists
										if data[x + y*sx + z*sx*sy]:
											data[x + y*sx + z*sx*sy] = op.material
									VoxelPaintStack.PAINT_MODE.ADD: # draw only if voxel is empty
										if not data[x + y*sx + z*sx*sy]:
											data[x + y*sx + z*sx*sy] = op.material
									VoxelPaintStack.PAINT_MODE.ERASE:
										if data[x + y*sx + z*sx*sy]:
											data[x + y*sx + z*sx*sy] = 0
									VoxelPaintStack.PAINT_MODE.NONE:
										pass

