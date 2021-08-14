extends Node

# Packet overhead around 37 bytes for unreliable.

const DEFAULT_PORT := 3342
const MAX_PLAYERS := 40
enum MOVE { # move instruc
	# vector2
	LOOK, # yaw and pitch
	# byte
	PROCESSED, # has been processed
	JUMP,
	X_DIR,
	Z_DIR,
	LOOK_DELTA} # did look change since last frame

enum STATE { # for snapshot / state
	# vector3
	POSITION,
	VELOCITY,
	# vector2
	LOOK, 
	# byte
	HEALTH,
	EQUIPPED_SLOT, # tells which weapon / ability and if reloading
	WEAPON_CHARGE, # frames since weapon last fired
	FIXED_CHARGE, # how many fixed abilities available
	TIMED_CHARGE, # frames since timed ability last used
	ULT_CHARGE}

var server_ip := "127.0.0.1"
var net_peer:NetworkedMultiplayerENet = null # enet peer for this client
var network_id:int
var is_online := false

var client_gamer:Gamer

var physics_delta = (
	1.0 / (ProjectSettings.get_setting("physics/common/physics_fps")))

func _ready():
	
#	var cps = PacketSerializer.new()
#	cps.test()
#	var rb = LagBuffer.new()
#	rb.test()
	var pb = PoolBuffer.new([
		PoolVector3Array([Vector3(10, 5, 8), Vector3(3, 2, 1)]),
		PoolVector3Array(),
		PoolVector2Array(),
		PoolByteArray(),
		PoolByteArray(),
		PoolByteArray(),
		PoolByteArray(),
		PoolByteArray()])
	pb.test()
	gaming(PoolByteArray())

func gaming(thing):
	thing.resize(1)
	thing[0] = 120
	print(thing[0])

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
		get_tree().set_network_peer(net_peer)
		if is_server:
			is_online = true
			network_id = 1
			get_tree().get_multiplayer().connect(
				"network_peer_packet",
				self,
				"_on_custom_packet_received"
				)
		else:
			network_id = get_tree().get_network_unique_id()
			net_peer.connect(
				"server_disconnected", 
				self, 
				"_on_disconnect")
			net_peer.connect(
				"connection_failed", 
				self, 
				"_on_disconnect")
			net_peer.connect(
				"connection_succeeded", 
				self, 
				"_on_connect")
		
		print(
			"Server started, waiting for players" 
			if is_server else
			"Client #%d created" % network_id)
	
func _player_connected(id):
	print("Player connected with id ", id)

func _on_disconnect():
	is_online = false

func _on_connect():
	is_online = true

var counter_0 = 0
func _on_custom_packet_received(id:int, packet:PoolByteArray):
	if network_id == 1:
		client_gamer.network_mover.receive_move_packet(id, packet)

func has_connected_peer() -> bool:
	var is_connected = false
	if network_id == 1:
		is_connected = (
			get_tree().multiplayer.get_network_connected_peers().size() > 0)
	else:
		is_connected = (
			get_tree().network_peer.get_connection_status() == 
			NetworkedMultiplayerPeer.CONNECTION_CONNECTED)
	return is_connected

func send_packet(packet:PoolByteArray, id:int):
	# client can only send packets to server
	if packet and (not packet.empty()) and is_online:
		if (network_id == 1 and id != 1) or (network_id !=1 and id ==1): # xor
			return get_tree().get_multiplayer().send_bytes(packet, id)
