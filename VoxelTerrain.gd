tool

extends Spatial

class_name VoxelTerrain

# Automatically manages VoxelNodes by chunks

# emitted when all chunks have been constructed
signal terrain_ready

var num_chunks_ready = 0

# TODO replace with export(VoxelConfiguration) once PR #44879 is merged into Godot
export(Resource) var configuration = null setget _set_configuration

export(Resource) var paint_stack = null setget _set_paint_stack

export var terrain_chunks : Vector3 = Vector3(1,1,1) setget _set_terrain_chunks
export var chunk_voxel_count : Vector3 = Vector3(32,32,32)  setget _set_chunk_voxel_count

export var lod_distance_min = 0.0 setget _set_lod_distance_min
export var lod_distance_max = 1024.0 setget _set_lod_distance_max


var _area_check_interval_frames : int = 60
export var area_check_interval_seconds : float = 1.0 setget _set_area_check_interval_seconds
var _area_check_counter = 0

export var auto_expand = false setget _set_auto_expand
export var auto_expand_distance : float = 64.0

export var max_chunk_count : int = 512


export var do_clear_terrain = false setget _set_do_clear_terrain
export var do_create_terrain = false setget _set_do_create_terrain
export var do_test_fill = false setget _set_do_test_fill

var _chunks = []
var _chunks_lookup = {} # Dictionary in form [x][y][z]

var _chunks_to_add = []
var _add_delay_frames = 2
var _add_delay_counter = 0

var is_ready = false


func _set_configuration(nv):
	configuration = nv
	for chunk in _chunks:
		if chunk.voxel_body:
			chunk.voxel_body.configuration = configuration


func _set_paint_stack(nv):
	#print("VoxelTerrain: set paint stack to %s" % nv)
	paint_stack = nv
	if paint_stack:
		for chunk in _chunks:
			if chunk.voxel_body:
				chunk.voxel_body.paint_stack = paint_stack


func _set_terrain_chunks(nv):
	terrain_chunks = nv
	create_terrain()


func _set_chunk_voxel_count(nv):
	chunk_voxel_count = nv
	create_terrain()


func _set_lod_distance_min(nv):
	lod_distance_min = nv
	update_lod_in_all_chunks()

func _set_lod_distance_max(nv):
	lod_distance_max = nv
	update_lod_in_all_chunks()

func update_lod_in_all_chunks():
	for chunk in _chunks:
		chunk.voxel_body.lod_distance_min = lod_distance_min
		chunk.voxel_body.lod_distance_max = lod_distance_max


func _set_area_check_interval_seconds(nv):
	area_check_interval_seconds = max(1.0/60.0, nv)
	_area_check_interval_frames = area_check_interval_seconds * 60.0

func _set_auto_expand(nv):
	auto_expand = nv
	if auto_expand and translation.length() != 0:
		push_warning("VoxelTerrain: auto_expand does not work when terrain is translated. Moving VoxelTerrain to (0,0,0)")
		translation = Vector3(0,0,0)
		clear_terrain()

func _set_do_clear_terrain(new_value):
	if new_value == false:
		do_clear_terrain = false
		return
	
	create_terrain()
	
	do_clear_terrain = false


func _set_do_create_terrain(new_value):
	if new_value == false:
		do_create_terrain = false
		return
	
	create_terrain()
	
	do_create_terrain = false


func _set_do_test_fill(nv):
	do_test_fill = nv
	
	create_terrain()
	

func get_total_count():
	return _chunks.size() * chunk_voxel_count.x * chunk_voxel_count.y * chunk_voxel_count.z


func _ready():
	set_physics_process(true)
	if not configuration:
		#print("VoxelTerrain: loading default configuration")
		configuration = VoxelHammer.default_configuration
	is_ready = true
	create_terrain()


func _physics_process(delta):
	_add_delay_counter +=1
	if _add_delay_counter > _add_delay_frames:
		_add_delay_counter = 0
		#Add waiting chunks
		var to_add = _chunks_to_add.pop_front()
		if to_add:
			_add_chunk(to_add)
	
	_area_check_counter += 1
	if _area_check_counter >= _area_check_interval_frames:
		_area_check_counter = 0
		
		#scan area (but wait add operations to finish first)
		if auto_expand and _chunks_to_add.size() == 0:
			var chunk_real_size = chunk_voxel_count * configuration.voxel_base_size
			var chunks_inside_area_x : int = ceil(auto_expand_distance / chunk_real_size.x) * 2
			var chunks_inside_area_y : int = ceil(auto_expand_distance / chunk_real_size.y) * 2
			var chunks_inside_area_z : int = ceil(auto_expand_distance / chunk_real_size.z) * 2
			
			var search_start_point = get_viewport().get_camera().translation / configuration.voxel_base_size
			var sp_local = Vector3()
			sp_local.x = search_start_point.x / chunk_voxel_count.x - chunks_inside_area_x/2 + 0.5
			sp_local.y = search_start_point.y / chunk_voxel_count.y - chunks_inside_area_x/2 + 0.5
			sp_local.z = search_start_point.z / chunk_voxel_count.z - chunks_inside_area_x/2 + 0.5
			
			for x in chunks_inside_area_x:
				for y in chunks_inside_area_y:
					for z in chunks_inside_area_z:
						if not lookup_get_chunk(floor(x+sp_local.x), floor(y+sp_local.y), floor(z+sp_local.z)):
							add_chunk(floor(x+sp_local.x), floor(y+sp_local.y), floor(z+sp_local.z))
		
		# if too many then drop first out of sight chunk from front of the array (propably oldest so propably farthest away)
		for n in range(5):
			if _chunks.size() > max_chunk_count:
				var candidate_for_removal = null
				var largest_found = 0
				for chunk in _chunks:
					if chunk.voxel_body and chunk.voxel_body.distance_to_tracked > largest_found:
						largest_found = chunk.voxel_body.distance_to_tracked
						candidate_for_removal = chunk
				if candidate_for_removal:
					#print("VoxelTerrain: Removing chunk")
					_chunks.erase(candidate_for_removal)
					lookup_remove_chunk(candidate_for_removal)
					remove_child(candidate_for_removal)
					candidate_for_removal.queue_free()
				else:
					push_warning("VoxelTerrain: Chunk count over max_chunk_count, yet cant find anything to remove. Too large auto_expand_distance?")


func clear_terrain():
	#print("Clearing terrain...")
	# Destroy old terrain	
	#var timer = DebugTimer.new("Clearing terrain")
	for child in _chunks:
		child.queue_free()
	_chunks.clear()
	
	_chunks_lookup.clear()
	
	#timer.end()


func create_terrain():
	#print("Creating terrain...")
	
	if not is_ready:
		return
	
	clear_terrain()
	
	num_chunks_ready = 0
	
	for x in range(terrain_chunks.x):
		for y in range(terrain_chunks.y):
			for z in range(terrain_chunks.z):
				#print("creating chunk")
				add_chunk(x,y,z)


func add_chunk(x : int, y : int, z : int):
	# Add only one chunk per frame to avoid stutters
	
	var new_chunk = VoxelTerrainChunk.new(configuration.voxel_base_size, chunk_voxel_count)
	new_chunk.index_x = x
	new_chunk.index_y = y
	new_chunk.index_z = z
	
	_chunks_to_add.push_back(new_chunk)


func _add_chunk(new_chunk):
	
	add_child(new_chunk)
	
	var real_x = new_chunk.index_x*chunk_voxel_count.x*configuration.voxel_base_size
	var real_y = new_chunk.index_y*chunk_voxel_count.y*configuration.voxel_base_size
	var real_z = new_chunk.index_z*chunk_voxel_count.z*configuration.voxel_base_size
	new_chunk.translate(Vector3(real_x, real_y, real_z))
	
	new_chunk.voxel_body.configuration = configuration
	new_chunk.voxel_body.paint_stack = paint_stack
	new_chunk.voxel_body.distance_tracking = VoxelNode.DISTANCE_MODE.CAMERA
	new_chunk.voxel_body.use_qubic_distance = true
	new_chunk.voxel_body.lod_tracking = true
	new_chunk.voxel_body.lod_distance_min = lod_distance_min
	new_chunk.voxel_body.lod_distance_max = lod_distance_max
	
	if do_test_fill:
		new_chunk.do_test_fill = do_test_fill
	
	new_chunk.voxel_body.connect("mesh_ready", self, "_on_chunk_mesh_ready")
	
	_chunks.push_front(new_chunk)
	
	lookup_add_chunk(new_chunk)
	
	return new_chunk


func lookup_add_chunk(chunk):
	#print("adding chunk %s" % Vector3(chunk.index_x, chunk.index_y, chunk.index_z))
	var x_dict = _chunks_lookup.get(chunk.index_x, null)
	if not x_dict:
		x_dict = {}
		_chunks_lookup[chunk.index_x] = x_dict
	
	var y_dict = x_dict.get(chunk.index_y, null)
	if not y_dict:
		y_dict = {}
		x_dict[chunk.index_y] = y_dict	
	
	var z_node = y_dict.get(chunk.index_z,null)
	if z_node:
		push_warning("VoxelTerrain: Trying to add terrain chunk to already occupied chunk index!")
		return null
	if not z_node:
		y_dict[chunk.index_z] = chunk
		return chunk


func lookup_remove_chunk(chunk):
	var x_dict = _chunks_lookup.get(chunk.index_x,null)
	if x_dict:
		var y_dict = x_dict.get(chunk.index_y,null)
		if y_dict:
			var z_node = y_dict.get(chunk.index_z,null)
			if z_node:
				y_dict.erase(chunk.index_z)
				return z_node
			else:
				push_warning("VoxelTerrain: Trying to remove non-existent chunk index!")
	return null


func lookup_get_chunk(x : int, y : int, z : int):
	var x_dict = _chunks_lookup.get(x,null)
	if x_dict:
		var y_dict = x_dict.get(y,null)
		if y_dict:
			return y_dict.get(z,null)
	return null


func _on_chunk_mesh_ready():
	#print("VoxelTerrain: Chunk mesh ready")
	num_chunks_ready += 1
	if num_chunks_ready == _chunks.size():
		print("VoxelTerrain: All Chunks ready")	
		emit_signal("terrain_ready")

