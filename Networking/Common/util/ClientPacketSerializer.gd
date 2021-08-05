extends Node

class_name ClientPacketSerializer

const OPCODE_MASK = 224
const BYTE_MASK = 255
const MAX_BYTES = 512

# We serialize to an existing PoolByteArray using indices changed right before 
# calling serialization functions. This reduces parameter count and avoids 
# runtime allocations
var bytes
var start_bit = 0
var end_bit = 0

# byte:  [ 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 ]
# most sig ^                           ^ least sig
# using big endian: [b0, b1] -> short = (b0 << 7) + (b1)
# operation codes (bits 7, 6, 5 of first byte in payload):
# 	000 : setup
# 	001 : movement
# 	010 : directed ability
# 	011 : undirected ability
# 	100 : chatstring
# 	101 : ping
# 	110 : 
# 	111 : 


# serialize_X_to_Kb means serializing a var of type X to K number of bytes

#func serialize__to_b():
#	check_valid_byte_array_and_indices()

#func deserialize__from_b() -> :
#	check_valid_byte_array_and_indices()

func _ready():
	bytes = PoolByteArray([])
	bytes.resize(20)
	
	# test short serialization
#	var test_short = 0x3342
#	start_bit = 0
#	end_bit = 1
#	serialize_ushort_to_2b(test_short)
#	end_bit = start_bit + 1
#	serialize_ushort_to_2b(0x99FF)
#	end_bit = start_bit + 1
#	serialize_ushort_to_2b(0xBEEF)
#	print("%02X" % bytes[0], "%02X" % bytes[1])
#	start_bit = 0
#	end_bit = 1
#	print("%04X" % deserialize_ushort_from_2b())
#	end_bit = start_bit + 1
#	print("%04X" % deserialize_ushort_from_2b())
#	end_bit = start_bit + 1
#	print("%04X" % deserialize_ushort_from_2b())
	# test yaw pitch serialization
	
	pass

func pb():
	if bytes:
		print(bytes.hex_encode())

# --------------------------------------------------------Movement Serialization

func serialize_movement(
	instruc_id : int,
	zdir_0 : int, # frame 0 is frame before current
	xdir_0 : int,
	zdir_1 : int, # frame 1 is frame currently processed on client
	xdir_1 : int, 
	jump_0 : int, 
	jump_1 : int, 
	yaw_0 : float, # yaw [0..360]
	pitch_0 : float, # pitch [-90..90]
	yaw_1 : float,  
	pitch_1 : float) -> PoolByteArray:
	
	var bytes := PoolByteArray()
	
	var header_byte := (
		(1 << 5) +
		(1 << 4) if jump_0 else 0 +
		(1 << 3) if jump_1 else 0 +
		(1 << 2) if ( # bit 2 = true if any WASD movement in either frame
			zdir_0 | 
			xdir_0 | 
			zdir_1 | 
			xdir_1) else 0)
	
	bytes.push_back(header_byte)
	
	return bytes

func check_valid_byte_array_and_indices():
	assert(
		bytes,
		"given byte array is null")
	assert(
		bytes,
		"given byte array is null")
	assert(
		start_bit >= 0 and start_bit < bytes.size(), 
		"start_bit out of range")
	assert(
		end_bit >= 0 and end_bit < bytes.size(), 
		"end_bit out of range")
	assert(
		end_bit >= start_bit,
		"end_bit must be after or at start_bit")

func serialize_ubyte_to_1b(ubyte:int): # writes to start_bit
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() > 0,
		"byte array must have at least 1 element")
	assert(
		ubyte >= 0 and ubyte < 256,
		"ubyte out of range")
	
	end_bit = start_bit
	
	bytes[start_bit] = ubyte
	
	start_bit = start_bit + 1

func deserialize_ubyte_from_1b() -> int:
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() > 0,
		"byte array must have at least 1 element")
	
	end_bit = start_bit
	
	var ubyte = bytes[start_bit]
	
	start_bit = start_bit + 1
	
	return ubyte

func serialize_ushort_to_2b(ushort:int):
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() >= 2,
		"byte array must have at least 2 elements")
	assert(
		end_bit == start_bit + 1,
		"end_bit must equal (start_bit + 1)")
	assert(
		ushort >= 0 and ushort < 65536,
		"ushort out of range")
	
	end_bit = start_bit + 1
	
	bytes[start_bit] = ushort >> 8
	bytes[end_bit] = ushort & BYTE_MASK
	
	start_bit = end_bit + 1

func deserialize_ushort_from_2b() -> int:
	check_valid_byte_array_and_indices()
	assert(
		bytes.size() >= 2,
		"byte array must have at least 2 elements")
	assert(
		end_bit == start_bit + 1,
		"end_bit must equal (start_bit + 1)")
	
	end_bit = start_bit + 1
	
	var ushort = (bytes[start_bit] << 8) + bytes[end_bit]
	
	start_bit = end_bit + 1
	
	return ushort

func serialize_yaw_to_2b(yaw : float): # yaw is [0..360] degrees
	var yaw_short = lerp(
		0,
		65535,
		deg_to_deg360(yaw) / 360.0)
	serialize_ushort_to_2b(yaw_short)

func deserialize_yaw_from_2b() -> float:
	var yaw = lerp(
		0.0, 
		360.0,
		deserialize_ushort_from_2b() / 65535.0)
	return yaw

func serialize_pitch_to_1b(pitch : float): # pitch is from [-90..90] degrees
	var pitch_byte = lerp(
		0,
		255,
		(pitch + 90.0) / 180.0)
	serialize_ubyte_to_1b(pitch_byte)

func deserialize_pitch_from_1b() -> float:
	return lerp(
		-90.0,
		90.0,
		deserialize_ubyte_from_1b() / 255.0)

func serialize_player_rotation_to_3b(rotation: Array):
	var yaw = rotation[0]
	var pitch = rotation[1]
	serialize_yaw_to_2b(yaw)
	serialize_pitch_to_1b(pitch)

func deserialize_player_rotation_from_3b() -> Array:
	var rotation = []
	rotation[0] = deserialize_yaw_from_2b()
	rotation[1] = deserialize_pitch_from_1b()
	return rotation

# a 1:1 function with domain and range 0.0 to 1.0 
# used to map normalized player camera pitch to a 6-bit int
# corresponds to:
# y = 0.5x WHEN 0 < x < 0.25
# y = 1.5x - 0.25 WHEN 0.25 < x < 0.75
# y = 0.5x + 0.5 WHEN 0.75 < x < 1.0
static func pitch_to_bit6_lerp_map(lerp_in: float) -> float:
	return lerp_in

# inverse of pitch_to_bit6_lerp_map
static func bit6_to_pitch_lerp_map(lerp_in: float):
	return lerp_in

static func deg_to_deg360(deg : float):
	deg = fmod(deg, 360.0)
	if deg < 0.0:
		deg += 360.0
	return deg

static func shortest_deg_between(deg1 : float, deg2 : float):
	deg1 = deg_to_deg360(deg1)
	deg2 = deg_to_deg360(deg2)
	return min(
		abs(deg1 - deg2),
		min(
			abs((deg1 - 360.0) - deg2),
			abs((deg2 - 360.0) - deg1)
			)
		)

func serialize_click():
	pass

func deserialize_click():
	pass
