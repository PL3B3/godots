extends Node

const DEFAULT_PORT = 42
const MAX_PLAYERS = 4

var players = {}
var info = { position = Vector2(0, 0), health = 200}

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

func start_server():
	var host = NetworkedMultiplayerENet.new()
	
	# compressing data packets -> big speed
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_ZLIB)
	
	var err = host.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if not err == OK:
		# if another server is running, this will execute
		
		printerr("Can't host, port already in use")
		return
	
	get_tree().set_network_peer(host)
	print("Server started, waiting for players")
	
func start_client():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client("127.0.0.1", DEFAULT_PORT)
	get_tree().set_network_peer(peer)
	
func _player_connected(id):
	rpc_id(id, "add_player", info)

func _player_disconnected(id):
	players.erase(id)
	
func _connected_ok():
	pass
	
func _connected_fail():
	pass

func _server_disconnected():
	quit_game()
	
func quit_game():
	get_tree().set_network_peer(null)
	players.clear()

func add_player(info):
	var id = get_tree().get_rpc_sender_id()
	players[id] = info

remote func register_player(id, info):
	pass
