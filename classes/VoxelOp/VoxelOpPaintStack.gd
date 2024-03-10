extends VoxelOperation

class_name VoxelOpPaintStack

var paint_stack

var local_position_offset = Vector3(0,0,0)
var local_scale = 1.0


func _init(paint_stack : VoxelPaintStack):
	super("VoxelOpPaintStack", VoxelOperation.CALCULATION_LEVEL.VOXEL+20)
	self.paint_stack = paint_stack


# Called in main thread before executing 'run_operation'
func prepare_run_operation():
	if paint_stack.use_global_coordinates:
		local_position_offset = voxel_instance.global_position
		local_scale = voxel_instance.mesh_scale


# This code is potentially executed in another thread!
func run_operation():
	#print("!!! VoxelOpPaintStack executing!")
	
	do_paint_stack(voxel_instance.voxel_data.data, voxel_instance.blend_buffer, voxel_instance.voxel_data.size, paint_stack, local_position_offset, local_scale)
	
	voxel_instance.voxel_data.call_deferred("notify_data_changed")


# This code is executed in another thread so it can not access voxel_node variable!
func do_paint_stack(data : PackedInt64Array, blend_buffer : PackedFloat32Array, size : Vector3i, paint_stack : VoxelPaintStack, position_offset : Vector3 = Vector3(0,0,0), scale = 1.0):
	#print("Applying Voxel Paint stack...")
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	var point : Vector3
	
	if paint_stack.clear_voxel_data:
		data.fill(0)
		
	if blend_buffer.is_empty():
		blend_buffer.resize(data.size())
	if paint_stack.clear_blend_buffer:
		blend_buffer.fill(0.0)
	
	for op in paint_stack.operation_stack:
		if op.active:
			for z in range(sz):
				for y in range(sy):
					for x in range(sx):
						
						if cancel:
							return
						
						point = Vector3(x,y,z)
						if paint_stack.use_global_coordinates:
							point *= scale
							point += position_offset
						
						var draw_at_point = false
						var blend_value_at_point = 0.0
						
						if op is PaintOpPlane:
							var plane_point = point.x
							match op.plane:
								VoxelPaintStack.AXIS_PLANE.Y:
									plane_point = point.y
								VoxelPaintStack.AXIS_PLANE.Z:
									plane_point = point.z
									
							if plane_point >= op.low - 0.5 and plane_point <= op.high - 0.5:
								draw_at_point = true
								blend_value_at_point = 1.0
						
						if op is PaintOpGradient:
							
							draw_at_point = true
							
							var plane_point = point.x
							match op.plane:
								VoxelPaintStack.AXIS_PLANE.Y:
									plane_point = point.y
								VoxelPaintStack.AXIS_PLANE.Z:
									plane_point = point.z
							
							var blend_amount = (op.offset - plane_point) / op.distance
							
							if op.mirror:
								blend_amount = 1 - clamp(abs(blend_amount), 0, 1.0)
							else:
								blend_amount = clamp(blend_amount, 0, 1.0)
							
							if op.reverse:
								blend_amount = 1 - blend_amount
								
							blend_value_at_point = blend_amount
							
						if op is PaintOpGradientVector:
							draw_at_point=true
							
							var plane = op.plane
							var plane_point = point / op.distance
							var dot = plane.dot(plane_point)
							
							if dot > 1.0:
								dot = 1.0
							if dot < 0:
								if op.mirror:
									dot = abs(dot)
								else:
									dot = 0
							
							dot = 1 - dot
							blend_value_at_point = dot
						
						if op is PaintOpSphere: 
							var distance2 = (point - op.center).length_squared()
							var radius2 = op.radius*op.radius
							if distance2 < radius2:
								draw_at_point = true
								blend_value_at_point = remap(distance2, 0, radius2, 1.0, 0.0)
							
						if op is PaintOpNoise:
							draw_at_point = true
							blend_value_at_point = (op.noise.get_noise_3d(point.x, point.y, point.z) + 1.0)
						
						
						# Write blend buffer
						blend_value_at_point *= op.blend_amount
						match op.blend_mode:
							VoxelPaintStack.BLEND_MODE.NORMAL:
								blend_buffer[x + y*sx + z*sx*sy] = blend_value_at_point
							VoxelPaintStack.BLEND_MODE.ADD:
								if not blend_buffer[x + y*sx + z*sx*sy]:
									blend_buffer[x + y*sx + z*sx*sy] = blend_value_at_point
								else:
									blend_buffer[x + y*sx + z*sx*sy] += blend_value_at_point
							VoxelPaintStack.BLEND_MODE.MINUS:
								if not blend_buffer[x + y*sx + z*sx*sy]:
									blend_buffer[x + y*sx + z*sx*sy] = -blend_value_at_point
								else:
									blend_buffer[x + y*sx + z*sx*sy] -= blend_value_at_point
							VoxelPaintStack.BLEND_MODE.ONE_MINUS:
								blend_buffer[x + y*sx + z*sx*sy] = 1 - blend_value_at_point
							VoxelPaintStack.BLEND_MODE.MULTIPLY:
								if blend_buffer[x + y*sx + z*sx*sy]:
									blend_buffer[x + y*sx + z*sx*sy] *= blend_value_at_point
							VoxelPaintStack.BLEND_MODE.NONE:
								pass
							
						#Write voxel data if blend at point is > 1.0
						if draw_at_point:
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

