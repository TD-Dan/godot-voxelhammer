@tool

extends VoxelOperation


class_name VoxelOpCreateMesh 

# !!! GODOT 4.0 bugs prevent threaded access to meshes or SurfaceTool in paraller: #73035 #56524 #70325

var mesh_buffer
var material_table


func _init():
	super("VoxOpCreateMesh", VoxelOperation.CALCULATION_LEVEL.MESH)


# This code is executed in another thread so it can not access voxel_node variable!
func run_operation():	
	#print("%s: run_operation on %s" % [self,voxel_instance])
	#print("!!! VoxelOpCreateMesh executing!")
	var mesh_empty = false
	
	var local_data_buffer
	var local_vis_buffer
	var local_buffer_dimensions
	
	if voxel_instance.visibility_count == 0:
		mesh_empty = true
	else:
		if voxel_instance.configuration.mesh_mode != VoxelConfiguration.MESH_MODE.NONE:
			voxel_instance.data_buffer_mutex.lock()
			local_data_buffer = voxel_instance.data_buffer.duplicate()
			local_vis_buffer = voxel_instance.vis_buffer.duplicate()
			local_buffer_dimensions = voxel_instance.voxel_data.size
			voxel_instance.data_buffer_mutex.unlock()
		
		match voxel_instance.configuration.mesh_mode:
			VoxelConfiguration.MESH_MODE.NONE:
				mesh_empty = true
			VoxelConfiguration.MESH_MODE.CUBES:
				construct_mesh_cubes(local_data_buffer, local_vis_buffer, local_buffer_dimensions)
			VoxelConfiguration.MESH_MODE.FACES:
				construct_mesh_faces(local_data_buffer, local_vis_buffer, local_buffer_dimensions)
			VoxelConfiguration.MESH_MODE.FAST:
				mesh_empty = true
				#construct_mesh_fast(local_data_buffer, local_vis_buffer, local_buffer_dimensions)
			_:
				call_deferred("push_warning", "VoxelOpCreateMesh: mesh mode unimplented -> cancelling")
				mesh_empty = true
		
	
	if cancel: return
	
	if mesh_empty:
		voxel_instance.call_deferred("set_mesh", null)
	else:
		# Assign right materials from configuration
		var conf_materials =  voxel_instance.configuration.materials
		if conf_materials.size() == 0:
				push_warning("%s: VoxelConfiguration material table is empty!")
		else:
			for j in range(material_table.size()):
				var si = material_table[j]
				if si >= conf_materials.size():
					si = 0
				mesh_buffer.surface_set_material(j, conf_materials[si])
		
		voxel_instance.call_deferred("set_mesh", mesh_buffer)
	
	voxel_instance.call_deferred("notify_mesh_calculated")


#Vertices of a cube
const cube_vertices = [[0,0,0],[1,0,0],[0,1,0],[1,0,0],[1,1,0],[0,1,0], #left -Z
				[1,0,1],[0,1,1],[1,1,1],[0,0,1],[0,1,1],[1,0,1], #right +Z
				[0,0,0],[0,0,1],[1,0,0],[1,0,1],[1,0,0],[0,0,1], #bottom -Y
				[0,1,0],[1,1,0],[0,1,1],[1,1,1],[0,1,1],[1,1,0], #top +Y
				[0,0,0],[0,1,0],[0,0,1],[0,1,0],[0,1,1],[0,0,1], #front -X
				[1,0,0],[1,0,1],[1,1,0],[1,0,1],[1,1,1],[1,1,0]] #back +X

const cube_normals = [[0,0,-1],[0,0,-1],[0,0,-1],[0,0,-1],[0,0,-1],[0,0,-1], #left -Z
				[0,0,1],[0,0,1],[0,0,1],[0,0,1],[0,0,1],[0,0,1], #right +Z
				[0,-1,0],[0,-1,0],[0,-1,0],[0,-1,0],[0,-1,0],[0,-1,0], #bottom -Y
				[0,1,0],[0,1,0],[0,1,0],[0,1,0],[0,1,0],[0,1,0], #top +Y
				[-1,0,0],[-1,0,0],[-1,0,0],[-1,0,0],[-1,0,0],[-1,0,0], #front -X
				[1,0,0],[1,0,0],[1,0,0],[1,0,0],[1,0,0],[1,0,0]] #back +X

const cube_uvs = [[0,0],[1,0],[0,1],[1,0],[1,1],[0,1], #left -Z
				[0,0],[1,1],[0,1],[1,0],[1,1],[0,0], #right +Z
				[1,0],[1,1],[0,0],[0,1],[0,0],[1,1], #bottom -Y !fix
				[0,0],[1,0],[0,1],[1,1],[0,1],[1,0], #top +Y
				[1,0],[1,1],[0,0],[1,1],[0,1],[0,0], #front -X
				[0,0],[1,0],[0,1],[1,0],[1,1],[0,1]] #back +X

func construct_mesh_cubes(data : PackedInt64Array, vis_buffer : PackedByteArray, size : Vector3i):
	#print("Constructing CUBES mesh...")
	# Creates cubes mesh from voxel data
	
	# Create one SurfaceTool per material
	var surface_tools = {}
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	var material_at_index= 0
	mesh_buffer = ArrayMesh.new()
	
	# Loop trough all indices (once only)
	for z in range(sz):
		for y in range(sy):
			# Guard SurfaceTool against paraller access, see GODOT bugs on top of file
			VoxelHammer.surface_tool_guard_mutex.lock()
			
			for x in range(sx):
				
				if cancel: return
		
				var ci : int = x + y*sx + z*sx*sy
				material_at_index = data[ci]
				
				if vis_buffer[ci] and material_at_index:
					if not material_at_index in surface_tools:
						#print("added surface tool %s" % material_at_index)
						surface_tools[material_at_index] = SurfaceTool.new()
						surface_tools[material_at_index].begin(Mesh.PRIMITIVE_TRIANGLES)
					var st : SurfaceTool = surface_tools[material_at_index]
					
					# TODO: implement as check from configuration materials
#					if smooth_buffer[ci]:
#						surface_tools[material_at_index].set_smooth_group(1)
#					else:
#						surface_tools[material_at_index].set_smooth_group(0)
					
					# Reminder to not test:
					# NO UV:s! Mesh generation is faster without and triplanar texturing makes things so much more easier
					# Triplanar causes flickering when material sampling is 'nearest'
					# NO append_from(): Its ~20-100x slower than add_vertex
					
					for i in cube_vertices.size():
						#st.set_uv(Vector2(1-cube_uvs[i][0],1-cube_uvs[i][1]))
						
						# TODO: control smooth group from material configuration, note: 0 is not no group (godot bug?), maybe set normal manually when no smoothing for now..
						#if config_mat[n].smooth = true:
						if material_at_index == 1:
							st.set_smooth_group(material_at_index)
						else:
							st.set_normal(Vector3(cube_normals[i][0],cube_normals[i][1],cube_normals[i][2]))
						
						#st.set_normal(Vector3(cube_normals[i][0],cube_normals[i][1],cube_normals[i][2]))
						st.add_vertex(Vector3(cube_vertices[i][0]+x,cube_vertices[i][1]+y,cube_vertices[i][2]+z))
			
			VoxelHammer.surface_tool_guard_mutex.unlock()
	
	# Add all surfaces to mesh
	
	var i = 0
	material_table = {}
	for key in surface_tools.keys():
		#surface_tools[key].index()
		surface_tools[key].generate_normals()
		surface_tools[key].generate_tangents()
		mesh_buffer.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tools[key].commit_to_arrays())
		material_table[i] = key
		i = i+1
	


# Faces of a cube
const cube_face_left = [[0,0,0],[1,0,0],[0,1,0],[1,0,0],[1,1,0],[0,1,0]]   # -x
const cube_face_right = [[1,0,1],[0,1,1],[1,1,1],[0,0,1],[0,1,1],[1,0,1]]  # x
const cube_face_bottom = [[0,0,0],[0,0,1],[1,0,0],[1,0,1],[1,0,0],[0,0,1]] # -y
const cube_face_top = [[0,1,0],[1,1,0],[0,1,1],[1,1,1],[0,1,1],[1,1,0]]    # y
const cube_face_front = [[0,0,0],[0,1,0],[0,0,1],[0,1,0],[0,1,1],[0,0,1]]  # -z
const cube_face_back = [[1,0,0],[1,0,1],[1,1,0],[1,0,1],[1,1,1],[1,1,0]]   # z

func construct_mesh_faces(data : PackedInt64Array, vis_buffer : PackedByteArray, size : Vector3i):
	#print("Constructing FACES mesh...")
	# Creates face mesh from voxel data
	
	
	# Create one SurfaceTool per material
	var surface_tools = {}
	
	var sx :int = size.x
	var sy :int = size.y
	var sz :int = size.z
	
	var largest_count : float = max(max(sx,sy),sz)
	var total : int = sx*sy*sz
	var smooth_group_active = false
	mesh_buffer = ArrayMesh.new()
	
	

	
	# Loop trough all indices
	for x in range(sx):
		for y in range(sy):
			# Guard SurfaceTool against paraller access, see GODOT bugs on top of file
			VoxelHammer.surface_tool_guard_mutex.lock()
	
			for z in range(sz):
				
				if cancel: return
				
				var ci : int = x + y*sx + z*sx*sy
				var material_at_index = data[ci]
				var visible_at_index = vis_buffer[ci]
				
				if material_at_index and visible_at_index:
					if not material_at_index in surface_tools:
						surface_tools[material_at_index] = SurfaceTool.new()
						surface_tools[material_at_index].begin(Mesh.PRIMITIVE_TRIANGLES)
					var st = surface_tools[material_at_index]
					
					# TODO: implement as material level check for smooth group
#					if smooth_buffer[ci]:
#						if not smooth_group_active:
#							surface_tools[material_at_index].add_smooth_group(true)
#							smooth_group_active = true
#					else:
#						surface_tools[material_at_index].add_smooth_group(false)
#						smooth_group_active = false
					
					# Reminder to not test:
					# NO UV:s! Mesh generation is faster without and triplanar texturing makes things so much more easier 
					# No add_triangle_fan(...): no way to alter vertex coordinates
					
					if x == 0 or not data[ci-1]:
						for vert in cube_face_front:
							st.add_vertex(Vector3(vert[0]+x,vert[1]+y,vert[2]+z))
					if x == sx-1 or not data[ci+1]:
						for vert in cube_face_back:
							st.add_vertex(Vector3(vert[0]+x,vert[1]+y,vert[2]+z))
					if y == 0 or not data[ci-sx]:
						for vert in cube_face_bottom:
							st.add_vertex(Vector3(vert[0]+x,vert[1]+y,vert[2]+z))
					if y == sy-1 or not data[ci+sx]:
						for vert in cube_face_top:
							st.add_vertex(Vector3(vert[0]+x,vert[1]+y,vert[2]+z))
					if z == 0 or not data[ci-sx*sy]:
						for vert in cube_face_left:
							st.add_vertex(Vector3(vert[0]+x,vert[1]+y,vert[2]+z))
					if z == sz-1 or not data[ci+sx*sy]:
						for vert in cube_face_right:
							st.add_vertex(Vector3(vert[0]+x,vert[1]+y,vert[2]+z))
	
			VoxelHammer.surface_tool_guard_mutex.unlock()
	
	# Add all surfaces to mesh
	var i = 0
	material_table = {}
	for key in surface_tools.keys():
		#surface_tools[key].index()
		surface_tools[key].generate_normals()
		surface_tools[key].generate_tangents()
		mesh_buffer.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tools[key].commit_to_arrays())
		material_table[i] = key
		i = i+1


#func construct_mesh_fast_native():
#	if cancel:
#		return
#
#	var native_worker = VoxelHammer.native_worker
#	if not native_worker:
#		push_warning("VoxelOpCreateMesh: Native worker not found. Falling back to ACCEL_MODE.NONE")
#		construct_mesh_fast()
#		return
#
#	var retarray = native_worker.create_mesh(voxel_data.voxel_count,material_buffer, smooth_buffer, vis_buffer)
#	mesh_buffer = retarray[0]
#	material_table = retarray[1]
#	#print("Got material_table: %s" % material_table)
#
#	for j in range(material_table.size()):
#		var si = material_table[j]
#		if si >= voxel_configuration.materials.size():
#			si = 0
#		mesh_buffer.surface_set_material(j, voxel_configuration.materials[si])
	
