extends Reference

class_name PoolBuffer

"""
	ringbuffer backed by parallel poolarrays
"""

const ID_MAX_SIZE_DEFAULT := 256
const TRAIL_BEHIND_DEFAULT := 2

var id_max_size = ID_MAX_SIZE_DEFAULT # how many states to store
var pools:Array

# when we receive our first packet, we move head to packet idx - trail_behind
# this gives us a safety buffer between the packet we're currently consuming
# and the most recent packet received, increasing the likelihood we will have
# all the needed packets in order by the time we process them
var trail_behind := TRAIL_BEHIND_DEFAULT

# the wrap threshold means we interpret very low id values like 0 or 15
# as being more "recent" than very high ones, like 255 if our id is 8-bit
# this is because the ids "wrap around" after reaching the max value
var wrap_threshold := trail_behind * 6


var head = 0 # next entry to consume (trails behind)
var tail = 0 # next idx to add an entry to

func _init(stubs:Array=[]):
	pools = []
	
	for i in range(stubs.size()):
		var arr = stubs[i] # need to copy poolarray to var to properly resize
		arr.resize(id_max_size)
		pools.push_back(arr)
	
	for pool in pools:
		print(pool[100])

# ----------------------------------------------------------------Writing Slices

func write(slice:Array, idx:int):
	idx = get_normalized_idx(idx)
	
	for i in range(min(pools.size(), slice.size())):
		pools[i][idx] = slice[i]

func write_first(slice:Array, idx:int):
	"""
	initializes the trail_behind window
	"""
	
	head = get_normalized_idx(idx - trail_behind)
	
	write(slice, idx)

func write_new(slice:Array, idx:int):
	"""
	only write if slice is more recent than head
	"""
	if get_relative_offset(head, idx) >= 0:
		write(slice, idx)

func write_tail(slice:Array):
	write(slice, tail)
	
	tail = get_normalized_idx(tail + 1)

func write_subslice(source:Array, sub_indices:PoolIntArray, idx:int):
	"""
		writes the values in source to their corresponding pools, based on the
		provided sub_indices
	"""
	idx = get_normalized_idx(idx)
	
	for i in range(source.size()):
		var sub_idx = get_normalized_var_idx(sub_indices[i])
		
		pools[sub_idx][idx] = source[i]

func write_var(value, var_id:int, idx:int):
	idx = get_normalized_idx(idx)
	var_id = int(clamp(var_id, 0, pools.size() - 1))
	
	pools[var_id][idx] = value

# ----------------------------------------------------------------Reading Slices

func read_to_array(idx:int, arr:Array):
	idx = get_normalized_idx(idx)
	assert(
		arr.size() >= pools.size(), 
		"Given array too small to write to")
	
	for i in range(min(pools.size(), arr.size())):
		arr[i] = pools[i][idx]

func read_head_to_array(arr:Array):
	read_to_array(head, arr)
	head = get_normalized_idx(head + 1)

func read_subslice_to_array(idx:int, sub_indices:PoolIntArray, target:Array):
	"""
		we read from the pools specified in sub_indices to the target array, in
		a contiguous fashion. In other words, the target and sub_indices arrays
		are the same size
	"""
	idx = get_normalized_idx(idx)
	
	var target_idx = 0
	for var_idx in sub_indices:
		var norm_var_idx = get_normalized_var_idx(var_idx) 
		target[target_idx] = pools[norm_var_idx][idx]
		target_idx += 1

func read_var_to_array(var_idx:int, idx:int, arr:Array):
	idx = get_normalized_idx(idx)
	var_idx = get_normalized_var_idx(var_idx)
	
	var value = pools[var_idx][idx]
	arr[var_idx] = pools[var_idx][idx]

func read(idx:int) -> Array:
	idx = get_normalized_idx(idx)
	
	var slice = []
	
	for array in pools:
		slice.push_back(array[idx])
	
	return slice

func read_head() -> Array:
	var data = read(head)
	head = get_normalized_idx(head + 1)
	return data

func read_subslice(idx:int, sub_indices:PoolIntArray) -> Array:
	idx = get_normalized_idx(idx)
	
	var subslice = []
	subslice.resize(sub_indices.size())
	
	var subslice_idx = 0
	for var_idx in sub_indices:
		var norm_var_idx = get_normalized_var_idx(var_idx)
		subslice[subslice_idx] = pools[norm_var_idx][idx]
		subslice_idx += 1
	
	return subslice

func read_var(var_idx:int, idx:int):
	var slice = read(idx)
	return slice[get_normalized_var_idx(var_idx)]

# -----------------------------------------------------------------idx Utility

func check_idx(idx:int):
	assert(
		idx < id_max_size and idx >= 0,
		"idx out of range, should be between [0...%d]" % (id_max_size - 1))

func check_sub_idx(var_id:int):
	assert(
		var_id < pools.size() and var_id >= 0,
		"idx out of range, should be between [0...%d]" % (pools.size() - 1))

func get_normalized_idx(idx:int) -> int:
	var norm_idx = idx % id_max_size
	
	if norm_idx < 0:
		norm_idx += id_max_size
	
	return norm_idx

func get_normalized_var_idx(var_idx:int) -> int:
	if var_idx < 0 or var_idx >= pools.size():
		print(
			"given var index is outside range, ",
			"make sure you're using the right enum")
	return int(clamp(var_idx, 0, pools.size() - 1))

func get_relative_offset(base_idx:int, new_idx:int):
	"""
	tells us if new_idx is to the right (positive return) or to the left 
	(negative return), accounting for the circular nature of the buffer
	"""
	base_idx = get_normalized_idx(base_idx)
	new_idx = get_normalized_idx(new_idx)
	
	return (
		new_idx + (
			id_max_size if 
			base_idx - new_idx > id_max_size - wrap_threshold
			else 0) - 
		base_idx)

# -----------------------------------------------------------------------Testing

func prb():
	for j in range(pools.size()):
		print(pools[j])

func test():
	var test_slice = [
		Vector3(22, 4193.89, -12.0),
		Vector3(7.5, 0, 0),
		Vector2(340.2, 17.85),
		15,
		66,
		2,
		190,
		74,
		100]
	
	write(test_slice, 200)
	
	print(read(200))
