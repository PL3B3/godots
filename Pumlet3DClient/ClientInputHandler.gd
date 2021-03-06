extends Node

onready var server = get_node("/root/Server")

enum DIRECTION {STOP, NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}

var player_controlled = null
var poll_cycle_ticks = 2

var current_sequence_number = 0
var motion_time_queue = preload("res://common/utils/MotionTimeQueue.tscn").instance()

func _ready():
	add_child(motion_time_queue)

func _on_our_player_spawned(our_player_node):
	player_controlled = our_player_node

# -------------------------------------------------------------------------Input

func _input(event):
	if not player_controlled == null:
		var command_to_send = player_controlled.handle_query_input(event)
		# client send cmd to server
		if (not command_to_send == []) and server.connected:
#			yield(get_tree().create_timer(server.simulated_ping), "timeout")
			server.send_player_rpc(command_to_send[0], command_to_send[1])

# Run per physics frame
#func _physics_process(delta):
#	if not player_controlled == null:
#		var direction_to_send = player_controlled.handle_poll_input()
#		# client send cmd to server
##		 and direction_to_send[1][0] != DIRECTION.STOP
#		if server.connected:
##			yield(get_tree().create_timer(server.simulated_ping), "timeout")
#			server.send_player_rpc_unreliable(direction_to_send[0], direction_to_send[1])
