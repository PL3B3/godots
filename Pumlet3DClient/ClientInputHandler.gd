extends Node

var player_controlled

func _ready():
	pass

# -------------------------------------------------------------------------Input

func _input(event):
	var command_to_send = player_controlled.handle_query_input(event)
	# client send cmd to server

# Run per physics frame
func _physics_process(delta):
	var direction_to_send = player_controlled.handle_poll_input()
	# client send cmd to server
