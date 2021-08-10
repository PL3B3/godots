extends Node

class_name NetworkGamerMovement

func doc():
	return
	"""
	on client: serialize and send player movement
	on server: buffer and deserialize player movement
	
	we send one movement instruction every two frames, after both have been 
	processed by client. we represent these two frames with a single dictionary
	for convenience:
	{
		has_been_processed,
		id, 
		jump_0, 
		z_dir_0, x_dir_0, 
		yaw_0, pitch_0, 
		jump_1, 
		z_dir_1, x_dir_1, 
		yaw_1, pitch_1}
	After processing this instruction on server side, we set the first flag
	to true, so that if our ringbuffer
	"""

var lbuf:LagBuffer
var sz:ClientPacketSerializer

var last_move_dict:Dictionary

func _ready():
	lbuf = LagBuffer.new()
	lbuf.init_rbuf()
	sz = ClientPacketSerializer.new()

func read_instruc_from_move_dict(move_dict:Dictionary):
	pass

func commit_instruc_to_buffer(instruc:PoolByteArray):
	pass

func write_move_dict_from_instruc(move_dict:Dictionary):
	pass

func _on_connection_succeeded():
	pass
