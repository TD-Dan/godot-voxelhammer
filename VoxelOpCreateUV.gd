extends VoxelOperation


class_name VoxelOpCreateUV

var surface_arrays_buffers = {}
var surface_format = {}
var surface_materials = {}

var new_mesh

func _init(voxel_data, voxel_configuration).(VoxelData.CALC_STATE.UV, voxel_data, voxel_configuration): 
	self.metadata.name = "VoxelOpCreateUV"


func to_string():
	return "[VoxelOpCreateUV]"


# Runs in main thread to prepare data
func prepare():
	if voxel_data.mesh:
		# make a copy of voxel data that can be modified in a different thread	
		for si in range(0,voxel_data.mesh.get_surface_count()):
			surface_arrays_buffers[si] = voxel_data.mesh.surface_get_arrays(si)
			surface_format[si] = voxel_data.mesh.surface_get_format(si)
			surface_materials[si] = voxel_data.mesh.surface_get_material(si)


# This code is executed in another thread so it can not access voxel_node variable!
func execute(thread_cache : Dictionary):
	#print("!!! VoxelOpCreateUV executing!")
		calculate_uvs_box()


func finalize():
	#print(" - VoxelOpCreateUV #%s: finalizing..." % ticket)
	if cancel:
		return
	# Update mesh
	voxel_data.replace_mesh(new_mesh, true)


func calculate_uvs_box():
	#print("Calculating uvs (box)...")
	new_mesh = ArrayMesh.new()
	var largest_count = voxel_data.largest_count
	for si in range(surface_arrays_buffers.size()):
		var surface = surface_arrays_buffers[si]
		if (surface_format[si] & Mesh.ARRAY_FORMAT_INDEX):
			print("Surface in index mode not supported by UV BOX calculation")
			cancel = true
			break
		var st = SurfaceTool.new()
		var uv = PoolVector2Array()
		var vertex_count = surface[Mesh.ARRAY_VERTEX].size()
		uv.resize(vertex_count)

		for i in range(0,vertex_count,3):
			var vertices = [surface[Mesh.ARRAY_VERTEX][i],surface[Mesh.ARRAY_VERTEX][i+1],surface[Mesh.ARRAY_VERTEX][i+2]]
			var vector1 = Vector3(vertices[0]-vertices[2])
			var vector2 = Vector3(vertices[0]-vertices[1])
			var face_normal = vector1.cross(vector2)
			face_normal = face_normal.normalized()
			var uvi1 = 0
			var uvi2 = 2
			var flip_u = true
			var flip_v = true
			if face_normal.y < -0.7:
				uvi1 = 0
				uvi2 = 2
				flip_v = false
			elif face_normal.x < -0.7:
				uvi1 = 2
				uvi2 = 1
				flip_u = false
			elif face_normal.x > 0.7:
				uvi1 = 2
				uvi2 = 1
			elif face_normal.z < -0.7:
				uvi1 = 0
				uvi2 = 1
				flip_u = true
				flip_v = true
			elif face_normal.z > 0.7:
				uvi1 = 0
				uvi2 = 1
				flip_u = false

			uv[i] = Vector2(vertices[0][uvi1]/largest_count,vertices[0][uvi2]/largest_count)
			uv[i+1] = Vector2(vertices[1][uvi1]/largest_count,vertices[1][uvi2]/largest_count)
			uv[i+2] = Vector2(vertices[2][uvi1]/largest_count,vertices[2][uvi2]/largest_count)

			if flip_u:
				uv[i].x = 1-uv[i].x
				uv[i+1].x = 1-uv[i+1].x
				uv[i+2].x = 1-uv[i+2].x
			if flip_v:
				uv[i].y = 1-uv[i].y
				uv[i+1].y = 1-uv[i+1].y
				uv[i+2].y = 1-uv[i+2].y

			#if i < 6:
				#print("vertices: %s normals: %s avg normal: %s uvs: %s" % [vertices, normals, face_normal, [uv[i],uv[i+1],uv[i+2]] ])
		
		surface[Mesh.ARRAY_TEX_UV] = uv
		surface[Mesh.ARRAY_TEX_UV2] = uv

		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
		new_mesh.surface_set_material(si, surface_materials[si])

