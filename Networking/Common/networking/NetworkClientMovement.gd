extends Node

class_name NetworkClientMovement

func doc():
	return (
	"""
	on client: serialize and send player movement
	on server: buffer and deserialize player movement
	
	we send one movement instruction every two frames, after both have been 
	processed by client. we represent these two frames with a single dictionary
	for convenience:
	{
		has_been_processed, #
		has_look_changed, # false if no yaw/pitch changes
		id, 
		jump_0, 
		z_dir_0, 
		x_dir_0, 
		yaw_0, 
		pitch_0, 
		jump_1, 
		z_dir_1, 
		x_dir_1, 
		yaw_1, 
		pitch_1}
	""")

enum MOVE { # move instruc
	PROC,
	JUMP,
	X,
	Z,
	LOOK_DELTA,
	YAW,
	PITCH}

var sz:PacketSerializer

var last_move_dict:Dictionary

func _ready():
	last_move_dict = {}
	sz = PacketSerializer.new()

func read_instruc_from_move_dict(move_dict:Dictionary) -> PoolByteArray:
	var look_delta_from_last = true
	if last_move_dict:
		look_delta_from_last = (
			(move_dict['yaw_0'] == last_move_dict['yaw_1']) and
			(move_dict['pitch_0'] == last_move_dict['pitch_1']) and
			(move_dict['yaw_1'] == move_dict['yaw_0']) and
			(move_dict['pitch_1'] == move_dict['pitch_0']))
	
	if look_delta_from_last:
		move_dict['has_look_changed'] = 0b_0000_0000
	else:
		move_dict['has_look_changed'] = 0b_0000_0100
	
	last_move_dict = move_dict.duplicate()
	
	var packet = sz.serialize_movement(move_dict)
	
	return packet

func send_move_packet(move_dict:Dictionary):
	Network.send_packet(read_instruc_from_move_dict(move_dict), 1)

func _on_connect():
	pass
