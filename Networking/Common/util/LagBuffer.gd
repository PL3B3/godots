extends Node

class_name LagBuffer

# generic ringbuffer, with an accessor that "lags behind" most recent entry

const ID_MAX_SIZE_DEFAULT = 256
const TRAIL_BEHIND_DEFAULT = 3
# the wrap threshold means we interpret very low id values like 0 or 15
# as being more "recent" than very high ones, like 255 if our id is 8-bit
# this is because the ids "wrap around" after reaching the max value
const WRAP_THRESHOLD_RATIO = 0.125

var id_max_size = ID_MAX_SIZE_DEFAULT # 256 for 8-bit id
var rbuf:Array

# when we receive our first packet, we move head to (packet index - trail_behind)
# this gives us a safety buffer between the packet we're currently consuming
# and the most recent packet received, increasing the likelihood we will have
# all the needed packets in order by the time we process them
var trail_behind = TRAIL_BEHIND_DEFAULT

# head is the next entry to consume
var head = 0

func init_rbuf(id_max_size:int=ID_MAX_SIZE_DEFAULT, 
trail_behind:int=TRAIL_BEHIND_DEFAULT):
	self.id_max_size = id_max_size
	
	rbuf = []
	rbuf.resize(id_max_size)

func fill_with_dicts():
	"""
	mmhmm
	"""
	for i in range(rbuf.size()):
		rbuf[i] = {}

func check_valid_index(index:int):
	assert(
		rbuf, 
		"rbuf must be initialized as a non empty array")
	assert(
		id_max_size == rbuf.size(), 
		"rbuf must be of length %d" % id_max_size)
	assert(
		index < id_max_size and index >= 0,
		"index out of range, should be between [0...%d]" % (id_max_size - 1))

func clear_rbuf():
	for i in range(rbuf.size()):
		rbuf[i] = null

func store_initial(data, index:int):
	store(data, index)
	head = get_normalized_index(index - trail_behind)

func store(data, index:int):
	check_valid_index(index)
	if get_relative_offset(head, index) >= 0: # instruc is "newer" than head
		rbuf[index] = data

func consume():
	var data = rbuf[head]
	head = get_normalized_index(head + 1)
	return data

func get_normalized_index(index:int) -> int:
	var norm_index = index % id_max_size
	
	if index < 0:
		norm_index += id_max_size
	
	return norm_index

func get_relative_offset(base_index:int, new_index:int):
	"""
	tells us if new_index is to the right (positive return) or to the left 
	(negative return), accounting for the circular nature of the buffer
	"""
	check_valid_index(base_index)
	check_valid_index(new_index)
	
	var wrap_thresh : int = int(WRAP_THRESHOLD_RATIO * id_max_size)
	
	return (
		new_index + (
			id_max_size if 
			base_index - new_index > id_max_size - wrap_thresh
			else 0) - 
		base_index)

func prb():
	var rbuf_str = ""
	for i in range(rbuf.size()):
		rbuf_str += ("rbuf[%03d] = %s \n" % [i, rbuf[i]])
	print(rbuf_str)

func _ready():
	pass
	init_rbuf()
	
func test_store_consume():
	store_initial({'x':2}, 2)
	print(str(consume()))
	store({'x':1}, 1)
	print(str(consume()))
	store({'x':4}, 4)
	print(str(consume()))
	store({'x':5}, 5)
	print(str(consume()))
	store({'x':3}, 3)
	print(str(consume()))
	print(str(consume()))
	print(str(consume()))
