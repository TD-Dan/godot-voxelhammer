extends Object

class_name SortedArray

## Sorted fixed size Array that keeps its elements always in sorted order
##
## Any value inserted must implement '_sorted_array_key' as int variable that
## dictates position of the value in the sorted array
##


var _order : Array = Array()

func get_array_for_read_only():
	return _order


func append_array(array : Array):
	_order.append_array(array)
	_order.sort_custom(func(a,b): return a._sorted_array_key < b._sorted_array_key)


## Insert into SortedArray using value._sorted_array_key to find the last right place
func insert(insert_at : int, value : Variant):
	value._sorted_array_key = insert_at
	var position = _order.bsearch_custom(value, func(a,b): return a._sorted_array_key < b._sorted_array_key, false)
	_order.insert(position, value)


## returns new position in the array
func update(value : Variant) -> int:
	if _order.size() < 2: return 1
	
	var current_position = _order.find(value)
	
	# swap position towards end as much as needed
	while current_position < _order.size()-1:
		if value._sorted_array_key > _order[current_position+1]._sorted_array_key:
			_order[current_position] = _order[current_position+1]
			_order[current_position+1] = value
			current_position += 1
		else:
			break
	
	# swap position towards beginning as much as needed
	while current_position > 0:
		if value._sorted_array_key < _order[current_position-1]._sorted_array_key:
			_order[current_position] = _order[current_position-1]
			_order[current_position-1] = value
			current_position -= 1
		else:
			break
	
	return current_position

func is_empty():
	return _order.is_empty()

func erase(value : Variant):
	_order.erase(value)

func remove_at(pos : int):
	_order.remove_at(pos)

func size():
	return _order.size()

