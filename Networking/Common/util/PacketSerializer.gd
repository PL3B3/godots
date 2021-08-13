extends StreamPeerBuffer

class_name PacketSerializer

func doc():
	return
	"""
	Common serialization class for major in-game networked instrucs
	
	client sent:
	- movement (max 30 / sec)
	- ability uses / firing weapon
	
	server sent:
	- player transforms snapshot (max 20 / sec)
	- health, death, vuln updates (ASAP, reliable)
	- map and gamemode state (ASAP, reliable)
	"""

enum { # client opcodes (bits 7, 6 of first byte in payload)
	CL_EXTENDED_OPCODE, # use next 6 bits for instruc
	CL_MOVEMENT, # movement
	CL_U_ABILITY, # undirected ability
	CL_D_ABILITY} # directed ability (precise position / direction info)

enum { # server opcodes (bits 7, 6 of first byte in payload)
	SV_EXTENDED_OPCODE, # use next 6 bits for instruc
	SV_SNAPSHOT, # movement
	SV_MAP_GAME, # undirected ability
	D_ABILITY} # directed ability (precise position / direction info)


const CLIENT_OPCODE_MASK = 0b_1100_0000
const BYTE_MASK = 0b_1111_1111
const FIRST_HALF_MASK = 0b_1111_0000
const SECOND_HALF_MASK = 0b_0000_1111
const MAX_BYTES = 256

func test():
	test_movement_serialization()

func test_movement_serialization():
	clear()
	var test_movement = {
		'has_been_processed' : 0,
		'has_look_changed' : 0,
		'id' : 0b_1001_1011, 
		'jump_0' : 0, 
		'z_dir_0' : 1, 
		'x_dir_0' : -1, 
		'yaw_0': 40.2356, 
		'pitch_0': 5.1134, 
		'jump_1': 3, 
		'z_dir_1':-1, 
		'x_dir_1':0, 
		'yaw_1':38.7777, 
		'pitch_1':2.8}
	# expected (little endian)
	# 0101 1000 HEADER
	# 1001 1011 ID
	# 0111 0100 WASD
	# 1001 1100 0001 1100 YAW 0 
	# 1000 0111 PITCH 0
	# 1001 0011 0001 1011 YAW 0
	# 1000 0011 PITCH 1
	var sz_move = serialize_movement(test_movement)
	print(hex_string_to_binary(sz_move.hex_encode()))
	var recv_movement = {}
	deserialize_movement(sz_move, recv_movement)
	print(recv_movement)
	
	clear()
	var test_movement_2 = {
		'has_been_processed' : 0,
		'has_look_changed' : 0,
		'id' : 0b_1001_1011, 
		'jump_0' : 0, 
		'z_dir_0' : 1, 
		'x_dir_0' : -1, 
		'yaw_0': 40.2356, 
		'pitch_0': 5.1134, 
		'jump_1': 3, 
		'z_dir_1':-1, 
		'x_dir_1':0, 
		'yaw_1':38.7777, 
		'pitch_1':2.8}
	"""
	print(dir_to_int(0, 0))
	print(dir_to_int(1, 0))
	print(dir_to_int(1, 1))
	print(dir_to_int(0, 1))
	print(dir_to_int(-1, 1))
	print(dir_to_int(-1, 0))
	print(dir_to_int(-1, -1))
	print(dir_to_int(0, -1))
	print(dir_to_int(1, -1))
	
	print(dir_from_int(0))
	print(dir_from_int(8))
	print(dir_from_int(3))
	"""

# --------------------------------------------------------Movement Serialization
func movement_serialization_doc():
	return (
	"""
	NAMENAMENAMENAMENAME,BYTES,DESC....
	--------------------------------------------------------------------------------
	Head                ,1    , opcode, jumps, tells if wasd or look delta 
	ID                  ,1    , movement id

	---------------------------------------------------------------OPTIONAL BY DELTA
	DIR                 ,1    , WASD info for both frames

	---------------------------------------------------------------OPTIONAL BY DELTA
	YAW0                ,2    
	PITCH0              ,1    

	---------------------------------------------------------------OPTIONAL BY DELTA
	YAW1                ,2
	PITCH1              ,1

	--------------------------------------------------------OPTIONAL FOR PACKET LOSS
	JDIR_CMP            ,1    , redundant last instruc dir
	YAW01               ,2    , avg yaw last instruc
	PITCH01             ,1    , avg pitch last instruc
	""")

func serialize_movement(move_dict:Dictionary) -> PoolByteArray:
	var has_wasd_movement = (
		move_dict['z_dir_0'] | 
		move_dict['x_dir_0'] | 
		move_dict['z_dir_1'] | 
		move_dict['x_dir_1'])
	
	var has_jump = (move_dict['jump_0'] | move_dict['jump_1'])
	
	var has_look_changed = move_dict['has_look_changed']
	
	var should_send_move = has_jump | has_look_changed | has_wasd_movement
	
	var packet := PoolByteArray()
	
	if should_send_move:
		var header_byte := (
			0b_0100_0000 +
			(0b_0010_0000 if move_dict['jump_0'] else 0) +
			(0b_0001_0000 if move_dict['jump_1'] else 0) +
			(0b_0000_1000 if has_wasd_movement else 0) + 
			(0b_0000_0100 if has_look_changed else 0))
		
		put_u8(header_byte)
		
		put_u8(move_dict['id'])
		
		if has_wasd_movement:
			var dir_byte := (
				(dir_to_int(move_dict['x_dir_0'], move_dict['z_dir_0']) << 4) +
				dir_to_int(move_dict['x_dir_1'], move_dict['z_dir_1']))
			
			put_u8(dir_byte)
		
		if has_look_changed:
			put_u16(convert_float_to_k_integer(
				move_dict['yaw_0'], 0.0, 360.0, 2))
			put_u8(convert_float_to_k_integer(
				move_dict['pitch_0'], -90.0, 90.0, 1))
			
			put_u16(convert_float_to_k_integer(
				move_dict['yaw_1'], 0.0, 360.0, 2))
			put_u8(convert_float_to_k_integer(
				move_dict['pitch_1'], -90.0, 90.0, 1))
		
		packet = data_array
	
	clear()
	
	return packet

func deserialize_movement(instruc:PoolByteArray, move_dict:Dictionary):
	clear()
	
	data_array = instruc
	
	var header_byte = get_u8()
	
	move_dict['jump_0'] = header_byte & 0b_0010_0000
	move_dict['jump_1'] = header_byte & 0b_0001_0000
	
	var has_wasd_movement = header_byte & 0b_0000_1000
	var has_look_changed = header_byte & 0b_0000_0100
	
	move_dict['has_look_changed'] = has_look_changed
	
	move_dict['id'] = get_u8()
	
	if has_wasd_movement:
		var dir_byte = get_u8()
		var first_frame_dir = dir_from_int(
			(dir_byte & FIRST_HALF_MASK) >> 4)
		var second_frame_dir = dir_from_int(
			dir_byte & SECOND_HALF_MASK)
		
		move_dict['x_dir_0'] = first_frame_dir.x_dir
		move_dict['z_dir_0'] = first_frame_dir.z_dir
		move_dict['x_dir_1'] = second_frame_dir.x_dir
		move_dict['z_dir_1'] = second_frame_dir.z_dir
	
	if has_look_changed:
		move_dict['yaw_0'] = read_float_from_k_integer(
			get_u16(), 0.0, 360.0, 2)
		move_dict['pitch_0'] = read_float_from_k_integer(
			get_u8(), -90.0, 90.0, 1)
		
		move_dict['yaw_1'] = read_float_from_k_integer(
			get_u16(), 0.0, 360.0, 2)
		move_dict['pitch_1'] = read_float_from_k_integer(
			get_u8(), -90.0, 90.0, 1)
	
	move_dict['has_been_processed'] = 0

static func dir_to_int(x_dir:int, z_dir:int) -> int:
	assert(
		z_dir >= -1 and z_dir <= 1 and x_dir >= -1 and x_dir <=1,
		"Directions must be between -1 and 1")
	
	var dir_int:int = 0
	
	match z_dir:
		-1:
			match x_dir:
				-1:
					dir_int = 5
				0:
					dir_int = 4
				1:
					dir_int = 3
		0:
			match x_dir:
				-1:
					dir_int = 6
				0:
					dir_int = 8
				1:
					dir_int = 2
		1:
			match x_dir:
				-1:
					dir_int = 7
				0:
					dir_int = 0
				1:
					dir_int = 1
	
	return dir_int

static func dir_from_int(dir_int) -> Dictionary:
	assert(
		dir_int >= 0 and dir_int <= 8, 
		"dir_int must be between [0..8]")
	
	var dir_dict = {
		'z_dir':0,
		'x_dir':0}
	
	match dir_int:
		0:
			dir_dict.z_dir = 1
			dir_dict.x_dir = 0
		1:
			dir_dict.z_dir = 1
			dir_dict.x_dir = 1
		2:
			dir_dict.z_dir = 0
			dir_dict.x_dir = 1
		3:
			dir_dict.z_dir = -1
			dir_dict.x_dir = 1
		4:
			dir_dict.z_dir = -1
			dir_dict.x_dir = 0
		5:
			dir_dict.z_dir = -1
			dir_dict.x_dir = -1
		6:
			dir_dict.z_dir = 0
			dir_dict.x_dir = -1
		7:
			dir_dict.z_dir = 1
			dir_dict.x_dir = -1
		8:
			dir_dict.z_dir = 0
			dir_dict.x_dir = 0
	
	return dir_dict

# -----------------------------------------------------------------------Utility

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

static func convert_float_to_k_integer(f:float, f_min:float, f_max:float, 
k:int) -> int:
	assert(
		f >= f_min and f <= f_max, 
		"float must be between specified range")
	assert(
		k >= 0 and k <= 4,
		"k must be between [0..4]")
	return int(lerp(
		0, 
		pow(256, k),
		(f - f_min) / (f_max - f_min)))

static func read_float_from_k_integer(i:int, f_min:float, f_max:float, 
k:int) -> float:
	assert(
	k >= 0 and k <= 4,
	"k must be between [0..4]")
	return lerp(
	f_min,
	f_max,
	i / pow(256, k))

static func hex_string_to_binary(hex_str:String) -> String:
	var b_str_arr = PoolStringArray()
	for i in hex_str.length():
		var append : String
		match hex_str[i]:
			'0':
				append = '0000'
			'1':
				append = '0001'
			'2':
				append = '0010'
			'3':
				append = '0011'
			'4':
				append = '0100'
			'5':
				append = '0101'
			'6':
				append = '0110'
			'7':
				append = '0111'
			'8':
				append = '1000'
			'9':
				append = '1001'
			'a':
				append = '1010'
			'b':
				append = '1011'
			'c':
				append = '1100'
			'd':
				append = '1101'
			'e':
				append = '1110'
			'f':
				append = '1111'
		
		b_str_arr.push_back(append)
	
	return String(b_str_arr)

func pd():
	print(hex_string_to_binary(data_array.hex_encode()))
