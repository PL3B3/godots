extends Node

onready var server = get_node("/root/Server")
var player_controlled = null


func _ready():
	pass

func _on_our_player_spawned(our_player_node):
	player_controlled = our_player_node

# -------------------------------------------------------------------------Input

func _input(event):
	if not player_controlled == null:
		var command_to_send = player_controlled.handle_query_input(event)
		# client send cmd to server
		if not command_to_send == []:
			server.send_player_rpc(command_to_send[0], command_to_send[1])

# Run per physics frame
func _physics_process(delta):
	if not player_controlled == null:
		var direction_to_send = player_controlled.handle_poll_input()
		# client send cmd to server
		server.send_player_rpc_unreliable(direction_to_send[0], direction_to_send[1])
