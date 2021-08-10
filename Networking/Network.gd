extends Node

# Packet overhead around 37 bytes for unreliable.

const DEFAULT_PORT := 3342
const MAX_PLAYERS := 40
var server_ip := "127.0.0.1"
var online := false
var net_peer : NetworkedMultiplayerENet = null # enet peer for this client
var network_id : int

var client_serializer = preload("res://Common/util/ClientPacketSerializer.gd")
var goodwater_map = preload("res://Goodwater.tscn")

var physics_delta = (
	1.0 / (
		ProjectSettings.get_setting(
			"physics/common/physics_fps"
			)
		)
	)

func _ready():
#	var serializer_test = client_serializer.new()
#	get_tree().get_root().call_deferred("add_child", serializer_test)
#	test_ringbuf()
	var cps = ClientPacketSerializer.new()
	get_tree().get_root().call_deferred("add_child", cps)
	var rb = LagBuffer.new()
	get_tree().get_root().call_deferred("add_child", rb)
	pass

func start_network(is_server: bool):
	net_peer = NetworkedMultiplayerENet.new()
	
	var err = null
	if is_server:
		err = net_peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	else:
		err = net_peer.create_client(server_ip, DEFAULT_PORT)
	
	if not err == OK:
		print("failed to create ", "server" if is_server else "client")
	else:
		network_id = 1 if is_server else get_tree().get_network_unique_id()
		
		get_tree().set_network_peer(net_peer)
		
		if is_server:
			online = true
			get_tree().get_multiplayer().connect(
				"network_peer_packet",
				self,
				"_on_custom_packet_received"
				)
		else:
			net_peer.connect(
				"server_disconnected", 
				self, 
				"_on_server_disconnect"
				)
			net_peer.connect(
				"connection_failed", 
				self, 
				"_on_server_disconnect"
				)
			net_peer.connect(
				"connection_succeeded", 
				self, 
				"_on_server_connection_succeeded"
				)
		
		print(
			"Server started, waiting for players" 
			if is_server else
			"Client #%d created" % network_id
			)
	
func _player_connected(id):
	print("Player connected with id ", id)

func _on_ButtonServer_pressed():
	start_network(true)
	get_tree().change_scene_to(goodwater_map)

func _on_ButtonClient_pressed():
	start_network(false)
	get_tree().change_scene_to(goodwater_map)

func _on_server_disconnect():
	online = false

func _on_server_connection_succeeded():
	online = true

func _on_custom_packet_received(id: int, packet: PoolByteArray):
	pass

func _physics_process(delta):
	if online and network_id != 1:
		get_tree().get_multiplayer().send_bytes(
				PoolByteArray([0]), 
				1
				)


