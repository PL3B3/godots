extends Node

class_name ServerPacketManager


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
"""

enum MOVE { # move instruc
	PROC,
	JUMP,
	X,
	Z,
	LOOK_DELTA,
	YAW,
	PITCH}

var lbuf:LagBuffer
var sz:PacketSerializer

var should_init_lagbuf = true # should we call "store_initial" on lagbuf
var last_move_dict:Dictionary

var avg_head_lag_behind := 0.0 # how many ticks is head behind new packet
var avg_weight_factor := 0.001 # how quickly our avg should adapt to new data
var acceptable_lag_overshot = 3 # (lbuf.trail_behind + this) is max lag behind before a reset

func _ready():
	last_move_dict = {}
	lbuf = LagBuffer.new()
	lbuf.init_rbuf()
	lbuf.fill_with_dicts()
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

func receive_move_packet(sender_id:int, instruc:PoolByteArray):
	var index = instruc[1]
	
	if should_init_lagbuf:
		write_instruc_to_move_dict(instruc, lbuf.get_handle_initial(index))
		should_init_lagbuf = false
	else:
		write_instruc_to_move_dict(instruc, lbuf.get_handle(index))
	
	var head_lag_behind = lbuf.get_relative_offset(lbuf.head, index)
	avg_head_lag_behind = (
		(head_lag_behind * avg_weight_factor) +
		(avg_head_lag_behind * (1.0 - avg_weight_factor)))
	
	if avg_head_lag_behind > lbuf.trail_behind + acceptable_lag_overshot:
		print(
			'head is lagging behind by %d ticks, triggering reset' %
			int(avg_head_lag_behind))
		lbuf.reset_head(index)

func write_instruc_to_move_dict(instruc:PoolByteArray, move_dict:Dictionary):
	if move_dict:
		sz.deserialize_movement(instruc, move_dict)
	else:
		print("cannot deserialize movement to null move_dict")

func _on_connection_succeeded():
	pass
