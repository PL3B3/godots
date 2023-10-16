extends Node

class_name NetworkMessenger

const SERVER_NETWORK_ID = 1

signal received_server_message(message)
signal received_client_message(sender_id, message)

var last_input_send_ts

func _ready():
	last_input_send_ts = Time.get_ticks_usec()

@rpc("any_peer", "call_remote", "unreliable")
func _handle_message_from_client(message):
	emit_signal("received_client_message", multiplayer.get_remote_sender_id(), message)

@rpc("authority", "call_remote", "unreliable")
func _handle_message_from_server(message):
	emit_signal("received_server_message", message)

func send_message_to_client(client_network_id, message):
	_handle_message_from_server.rpc_id(client_network_id, message)

func send_message_to_server(message):
#	print(Time.get_ticks_usec() - last_input_send_ts)
	last_input_send_ts = Time.get_ticks_usec()
	_handle_message_from_client.rpc_id(SERVER_NETWORK_ID, message)
