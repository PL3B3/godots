extends StreamPeerBuffer

class_name PacketSerializer

const OPCODE_MASK = 224
const BYTE_MASK = 255
const MAX_BYTES = 512

"""
We serialize to an existing PoolByteArray using indices changed right before 
calling serialization functions. This reduces parameter count and minimizes
runtime allocations

Every packet includes the information needed to 
"""
var bytes
var start_byte = 0
var end_byte = 0

# byte:  [ 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 ]
# most sig ^                           ^ least sig
# using big endian: [byte0, byte1] -> short = (byte0 << 8) + (byte1)

# serialize_X_to_Kb means serializing a var of type X to K number of bytes

#func serialize__to_b():
#	check_valid_byte_array_and_indices()

#func deserialize__from_b() -> :
#	check_valid_byte_array_and_indices()

func _ready():
	bytes = PoolByteArray()
	bytes.resize(20)
	
	serialize_k_integer_to_k_b(0x14ABCD, 3)
	serialize_k_integer_to_k_b(0xEF987654, 4)
	serialize_k_integer_to_k_b(0xEF987654, 4)
	serialize_k_integer_to_k_b(0xEF987654, 4)
	
	pbt()

func pbt():
	if bytes:
		print(bytes.hex_encode())

func pre_serialization(external_byte_array:PoolByteArray, start:int):
	bytes = external_byte_array
	start_byte = start
	end_byte = start_byte
	check_valid_byte_array_and_indices()

func check_valid_byte_array_and_indices():
	assert(
		bytes,
		"given byte array is null")
	assert(
		bytes,
		"given byte array is null")
	assert(
		start_byte >= 0 and start_byte < bytes.size(), 
		"start_byte out of range")
	assert(
		end_byte >= 0 and end_byte < bytes.size(), 
		"end_byte out of range")
	assert(
		end_byte >= start_byte,
		"end_byte must be after or at start_byte")

func serialize_ubyte_to_1b(ubyte:int): # writes to start_byte
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() > 0,
		"byte array must have at least 1 element")
	assert(
		ubyte >= 0 and ubyte < 256,
		"ubyte out of range")
	
	end_byte = start_byte
	
	bytes[start_byte] = ubyte
	
	start_byte = start_byte + 1

func deserialize_ubyte_from_1b() -> int:
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() > 0,
		"byte array must have at least 1 element")
	
	end_byte = start_byte
	
	var ubyte = bytes[start_byte]
	
	start_byte = start_byte + 1
	
	return ubyte

func serialize_ushort_to_2b(ushort:int):
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() >= 2,
		"byte array must have at least 2 elements")
	assert(
		end_byte == start_byte + 1,
		"end_byte must equal (start_byte + 1)")
	assert(
		ushort >= 0 and ushort < 65536,
		"ushort out of range")
	
	end_byte = start_byte + 1
	
	bytes[start_byte] = ushort >> 8
	bytes[end_byte] = ushort & BYTE_MASK
	
	start_byte = end_byte + 1

func deserialize_ushort_from_2b() -> int:
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() >= 2,
		"byte array must have at least 2 elements")
	assert(
		end_byte == start_byte + 1,
		"end_byte must equal (start_byte + 1)")
	
	end_byte = start_byte + 1
	
	var ushort = (bytes[start_byte] << 8) + bytes[end_byte]
	
	start_byte = end_byte + 1
	
	return ushort

func serialize_k_integer_to_k_b(num:int, k:int):
	assert(
		k > 0 and k <= 4,
		"k must be between [1..4]")
	
	end_byte = start_byte + (k - 1)
	
	check_valid_byte_array_and_indices()
	
	for i in range(k):
		bytes[start_byte + i] = (
			(num >> ((k - 1 - i) * 8)) &
			BYTE_MASK)
	
	start_byte = end_byte + 1

func deserialize_k_integer_from_k_b(k:int) -> int:
	assert(
		k > 0 and k <= 4,
		"k must be between [1..4]")
	
	end_byte = start_byte + (k - 1)
	
	check_valid_byte_array_and_indices()
	
	var k_int = 0
	
	for i in range(k):
		k_int += (
			bytes[start_byte + i] << 
			((k - 1 - i) * 8))
	
	start_byte = end_byte + 1
	
	return k_int



func is_fully_processed() -> bool:
	assert(
		bytes,
		"bytes must not be null")
	return start_byte >= bytes.size()

static func convert_float_to_integer(f:float, f_min:float, f_max:float, 
int_len_bytes:int) -> int:
	return int(lerp(
		0, 
		pow(256, min(int_len_bytes, 4)),
		(f - f_min) / (f_max - f_min)))

static func read_float_from_integer(i:int, f_min:float, f_max:float, 
int_len_bytes:int) -> float:
	return lerp(
		f_min,
		f_max,
		i / pow(256, min(int_len_bytes, 4)))

func test_short_serialization():
	# test short serialization
	var test_short = 0x3342
	start_byte = 0
	end_byte = 1
	serialize_ushort_to_2b(test_short)
	end_byte = start_byte + 1
	serialize_ushort_to_2b(0x99FF)
	end_byte = start_byte + 1
	serialize_ushort_to_2b(0xBEEF)
	print("%02X" % bytes[0], "%02X" % bytes[1])
	start_byte = 0
	end_byte = 1
	print("%04X" % deserialize_ushort_from_2b())
	end_byte = start_byte + 1
	print("%04X" % deserialize_ushort_from_2b())
	end_byte = start_byte + 1
	print("%04X" % deserialize_ushort_from_2b())
