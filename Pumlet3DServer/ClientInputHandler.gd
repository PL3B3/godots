extends Node

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

# Run per physics frame
func _physics_process(delta):
	if not player_controlled == null:
		var direction_to_send = player_controlled.handle_poll_input()
		# client send cmd to server
