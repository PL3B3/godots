extends Node

class_name InstrucBuffer

# byte ringbuffer holding serialized snapshots / instructions
# the instruc returned by consume() lags behind the latest instruc added

const ID_MAX_SIZE_DEFAULT = 256
const INSTRUC_MAX_SIZE_DEFAULT = 200
const TRAIL_BEHIND_DEFAULT = 3
# the wrap threshold means we interpret very low id values like 0 or 15
# as being more "recent" than very high ones, like 255 if our id is 8-bit
# this is because the ids "wrap around" after reaching the max value
const WRAP_THRESHOLD_RATIO = 0.125

var id_max_size = ID_MAX_SIZE_DEFAULT # max num of ids including 0, not max id value
var instruc_max_size = INSTRUC_MAX_SIZE_DEFAULT # max size of instruc in bytes
var buffer_size = ID_MAX_SIZE_DEFAULT * INSTRUC_MAX_SIZE_DEFAULT
var buffer:PoolByteArray

# when we receive our first packet, we move head to (packet index - trail_behind)
# this gives us a safety buffer between the packet we're currently consuming
# and the most recent packet received, increasing the likelihood we will have
# all the needed packets in order by the time we process them
var trail_behind = TRAIL_BEHIND_DEFAULT

# head is the next entry to consume
var head = 0

func init_buffer(id_max_size:int=ID_MAX_SIZE_DEFAULT, 
instruc_max_size:int=INSTRUC_MAX_SIZE_DEFAULT):
	self.id_max_size = id_max_size
	self.instruc_max_size = instruc_max_size
	self.buffer_size = id_max_size * instruc_max_size
	
	buffer = PoolByteArray()
	buffer.resize(buffer_size)
	clear_buffer()

func check_valid_index(index:int):
	assert(
		index < id_max_size and index >= 0,
		"index out of range, should be between [0...%d]" % (id_max_size - 1))

func clear_buffer():
	for i in range(buffer.size()):
		buffer[i] = 0

func clear_instruc(index:int):
	check_valid_index(index)
	
	var clear_index = index * instruc_max_size
	for i in range(instruc_max_size):
		buffer.set(clear_index, 0)
		clear_index += 1

func store_first_packet(instruc:PoolByteArray, index:int):
	store(instruc, index)
	head = get_normalized_index(index - trail_behind)

func store(instruc:PoolByteArray, index:int):
	if get_relative_offset(head, index) >= 0: # instruc is "newer" than head
		instruc_copy(instruc, index)

func instruc_copy(instruc:PoolByteArray, index:int):
	assert(
		instruc, 
		"instruction must not be null")
	assert(
		instruc.size() <= instruc_max_size, 
		"given instruction must be %d byte(s) or smaller" % instruc_max_size)
	check_valid_index(index)
	
	var write_to = index * instruc_max_size
	for i in range(instruc_max_size):
		if i < instruc.size():
			buffer[write_to] = instruc[i]
		else:
			buffer[write_to] = 0
		write_to += 1

func consume():
	var current_instruc_start = head * instruc_max_size
	var current_instruc = buffer.subarray(
		current_instruc_start,
		current_instruc_start + instruc_max_size - 1)
	clear_instruc(head)
	head = get_normalized_index(head + 1)
	
	return current_instruc

func get_normalized_index(index:int) -> int:
	var norm_index = index
	
	if index < 0:
		norm_index += id_max_size
	elif index >= id_max_size:
		norm_index -= id_max_size
	
	return norm_index

# tells us if new_index is to the right (positive return) or to the left 
# (negative return), accounting for the circular nature of the buffer
func get_relative_offset(base_index:int, new_index:int):
	assert((
			base_index >= 0 and 
			base_index < id_max_size and 
			new_index >= 0 and 
			new_index < id_max_size),
		"index out of bounds")
	
	var wrap_thresh : int = int(WRAP_THRESHOLD_RATIO * id_max_size)
	
	return (new_index + (
			id_max_size if 
			base_index - new_index > id_max_size - wrap_thresh
			else 0) - 
		base_index)

# the exact byte index where the instruction begins
func get_byte_index_of_instruc(index:int):
	check_valid_index(index)
	return index * instruc_max_size

# if instruc at index is all 0's
func get_is_instruc_null(index:int):
	var null_instruc:bool = true
	var start = get_byte_index_of_instruc(index)
	for i in range(instruc_max_size):
		null_instruc = null_instruc and (buffer[start + i] == 0)
	return null_instruc

func _ready():
	pass
	init_buffer(32,4)
#	test_store_and_consume()
#	test_instruc_copy()
#	test_is_instruc_null()
#	test_get_offset()

func test_store_and_consume():
	store_first_packet(PoolByteArray([0xAB, 0x55, 0x1F, 0x94]), 1)
	print(consume().hex_encode())
	store(PoolByteArray([0xEF, 0x39, 0x16, 0xC8]), 4)
	print(consume().hex_encode())
	store(PoolByteArray([0x11, 0x4B, 0x2B, 0x4A]), 2)
	print(consume().hex_encode())
	store(PoolByteArray([0x63, 0xF7, 0x89, 0x12]), 3)
	print(consume().hex_encode())
	store(PoolByteArray([0x14, 0x72, 0xB3, 0xBB]), 5)
	print(consume().hex_encode())
	store(PoolByteArray([0x45, 0x9C, 0xA1, 0xC9]), 6)
	print(consume().hex_encode())
	print(consume().hex_encode())
	print(consume().hex_encode())
	print(consume().hex_encode())
	print(consume().hex_encode())
	print(consume().hex_encode())
	pbf()

func test_get_offset():
	var test_offset = get_relative_offset(255, 12)
	assert(test_offset == 13)
	assert(10 == get_relative_offset(250, 4))
	test_offset = get_relative_offset(250, 220)
	assert(-30 == test_offset)
	test_offset = get_relative_offset(20, 4)
	assert(-16 == test_offset)
	test_offset = get_relative_offset(4, 20)
	assert(16 == test_offset)
	test_offset = get_relative_offset(2, 200)
	assert(198 == test_offset)
	test_offset = get_relative_offset(0, 255)
	assert(255 == test_offset)
	test_offset = get_relative_offset(255, 255)
	assert(0== test_offset)
	test_offset = get_relative_offset(255, 30)
	assert(31==test_offset)
	test_offset = get_relative_offset(255, 31)
	assert(-224==test_offset)

func test_instruc_copy():
	instruc_copy(
		PoolByteArray([0xAB, 0x55, 0x1F, 0x94]),
		5)
	instruc_copy(
		PoolByteArray([0xAB, 0x55, 0x1F, 0x94]),
		5)
	instruc_copy(
		PoolByteArray([0xEF, 0x39, 0x16, 0xC8]),
		0)
	instruc_copy(
		PoolByteArray([0x11, 0x4B, 0x2B, 0x4A]),
		1)
	instruc_copy(
		PoolByteArray([0x63, 0xF7, 0x89, 0x12]),
		2)
	instruc_copy(
		PoolByteArray([0x98]),
		31)
	pbf()

func test_is_instruc_null():
	print(get_is_instruc_null(31))

func pbf():
	var buf_str = ""
	var line_lim = 141
	var char_counter = 0
	for byte in buffer:
		buf_str += ("%02X|" % byte)
		char_counter += 3
		if char_counter >= line_lim:
			buf_str += "\n"
			char_counter = 0
	print(buf_str)
