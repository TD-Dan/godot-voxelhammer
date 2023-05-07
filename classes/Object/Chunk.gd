@tool

extends Object

class_name Chunk

var position : Vector3i = Vector3i.ZERO
var size : int = 16

var data : Dictionary = Dictionary()

var active = false

func save_to_disk(full_filename_and_path):
		var packet = PackedScene.new()
		var save_node = Node.new()
		var error = packet.pack(save_node)
		if error:
			push_error("Chunk packing for saving failed: %s" % error_string(error))
		error = ResourceSaver.save(packet, full_filename_and_path)
		if error:
			push_error("Chunk save to %s failed: %s" % [full_filename_and_path, error_string(error)])


func get_filename() -> String:
	return "_%s_%s_%s" % [position.x/size, position.y/size, position.z/size]
