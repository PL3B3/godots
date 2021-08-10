extends PacketSerializer

class_name ClientPacketSerializer

# operation codes (bits 7, 6 of first byte in payload):
# 	00 : extended opcodes (use next 6 bits, but never 8 zeroes)
# 	01 : movement
# 	10 : undirected ability
# 	11 : directed ability (precise position / direction info)

# --------------------------------------------------------Movement Serialization

func serialize_movement(move_dict:Dictionary):
	var bytes := PoolByteArray()
	
	var header_byte := (
		(1 << 6) +
		(1 << 5) if move_dict['jump_0'] else 0 +
		(1 << 4) if move_dict['jump_1'] else 0 +
		(1 << 3) if ( # bit 2 = true if any WASD movement in either frame
			move_dict['z_dir_0'] | 
			move_dict['x_dir_0'] | 
			move_dict['z_dir_1'] | 
			move_dict['x_dir_1']) else 0)
	
	bytes.push_back(header_byte)
	
	return bytes

func deserialize_movement(move_dict:Dictionary):
	pass

func serialize_backup_movement(move_dict:Dictionary):
	pass

func deserialize_backup_movement(move_dict:Dictionary):
	pass

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
