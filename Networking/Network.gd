extends Node

func _ready():
	pass

func start_server():
	var server = NetworkedMultiplayerENet.new()
	var err = server.create_server(4242, 4)
	if not err == OK:
		print("server creation failed")
		return
	
	get_tree().set_network_peer(server)
	
#	server.connect('network_peer_connected', self, '_player_connected')
	get_tree().connect("network_peer_connected", self, "_player_connected")

	
func connect_client():
	var client = NetworkedMultiplayerENet.new()
	
	var err = client.create_client('127.0.0.1', 4242)
	if not err == OK:
		print("client connection failed")
		return
	
	get_tree().set_network_peer(client)
	
#	client.connect("connected_to_server", self, "_player_connected")
	get_tree().connect("connected_to_server", self, "_player_connected")

	
func _player_connected(id):
	print("Player connected with id ", id)

func _on_ButtonServer_pressed():
	var server = NetworkedMultiplayerENet.new()
	var err = server.create_server(4242, 4)
	if not err == OK:
		print("server creation failed")
		return
	
	get_tree().set_network_peer(server)
	
#	server.connect('network_peer_connected', self, '_player_connected')
	get_tree().connect("network_peer_connected", self, "_player_connected")



func _on_ButtonClient_pressed():
	var client = NetworkedMultiplayerENet.new()
	
	var err = client.create_client('127.0.0.1', 4242)
	if not err == OK:
		print("client connection failed")
		return
	
	get_tree().set_network_peer(client)
	
#	client.connect("connected_to_server", self, "_player_connected")
	get_tree().connect("connected_to_server", self, "_player_connected")

