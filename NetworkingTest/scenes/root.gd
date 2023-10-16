extends Control

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected


func _ready():
	if start_server():
		# hacky: server already created, so create client instead
		get_tree().change_scene_to_file("res://scenes/client.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/server.tscn")


func start_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(Network.PORT)
	if error: 
		return error
	multiplayer.multiplayer_peer = peer


func _start_client():
	get_tree().change_scene_to_file("res://scenes/client.tscn")


func _start_server():
	get_tree().change_scene_to_file("res://scenes/server.tscn")

func _on_player_connected(id):
	pass

func _on_player_disconnected(id):
	player_disconnected.emit(id)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()


func _on_connected_fail():
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()

func wait_random():
	var timeout = RandomNumberGenerator.new().randf_range(0.5,1.0)
	await get_tree().create_timer(timeout).timeout
