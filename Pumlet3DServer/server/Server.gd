extends Node

##
## This is the dedicated server node
##

# homepubip is 174.70.104.137 haha don't use this against me

# The server sends authoritative players info to update, which the client_side physics_process works on
# Per each physics process cycle on this server, send
# A dictionary

const DEFAULT_PORT = 3342
const MAX_PLAYERS = 8
# Used to convert between ability name and its index in the ability_usable array
const ability_conversions = {
	"mouse_ability_0" : 0,
	"mouse_ability_1" : 1, 
	"key_ability_0" : 2, 
	"key_ability_1" : 3, 
	"key_ability_2" : 4
}

var physics_processing = false
var players = {}
var server_delta = 1.0 / (ProjectSettings.get_setting("physics/common/physics_fps"))

func _ready():
	start_server()

	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

remote func print_thing():
	print("i printed a boi")

func start_server():
	var server = NetworkedMultiplayerENet.new()
	
	# compressing data packets -> big speed
	server.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_ZSTD)

	var err = server.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if not err == OK:
		# if another server is running, this will execute
		print("server creation failed")
		# printerr("Can't host, port already in use")
		return
	
	get_tree().set_network_peer(server)
	print("Server started, waiting for players")

func _player_connected(id):
	print("Player with id ", id, " connected")
	
	# call the recently connected player to send its class type
	rpc_id(id, "parse_server_rpc", "send_blueprint", [])
	# rpc_id(id, "parse"say_zx")
	print(get_tree().get_network_connected_peers())

func _player_disconnected(id):
	players.erase(id)
	print("Player " + str(id) + " disconnected")
	#var disconnected_players_phantom = get_node("/root/ChubbyServer/" + str(id))
	#remove_child(disconnected_players_phantom)
	#disconnected_players_phantom.queue_free()
	#send_server_rpc_to_all_players("remove_other_player", [id])

func _connected_ok():
	print("got a connection")

func _connected_fail():
	pass

func _server_disconnected():
	quit_game()
	
# TODO: update the removing child thing to remove children from the right location (where they are added in player connected)
func quit_game():
	# make all peers quit game
	rpc("quit_game")
	
	# empties the dict holding player info
	players.clear()
	
	# removes player nodes from existence
	for n in get_tree().get_children():
		get_tree().remove_child(n)
		n.queue_free()

##
## these following 4 functions send all server commands to clients
##

# tcp (reliable) sends server command to all connected peers with specified args
func send_server_rpc_to_all_players(server_cmd, args):
	rpc("parse_server_rpc", server_cmd, args)

# udp (unreliable) sends server command to all connected peers with specified args
func send_server_rpc_to_all_players_unreliable(server_cmd, args):
	rpc_unreliable("parse_server_rpc", server_cmd, args)

# tcp (reliable) sends a server command to specified client with args
func send_server_rpc_to_one_player(player_id, server_cmd, args):
	rpc_id(player_id, "parse_server_rpc", server_cmd, args)

# udp (unreliable) equivalent to above
func send_server_rpc_to_one_player_unreliable(player_id, server_cmd, args):
	rpc_unreliable_id(player_id, "parse_server_rpc", server_cmd, args)
	
func send_server_rpc_to_specified_players(sync_dict, server_cmd, args):
	for id in sync_dict:
		if sync_dict[id]:
			send_server_rpc_to_one_player(id, server_cmd, args)
	
func send_server_rpc_to_specified_players_unreliable(sync_dict, server_cmd, args):
	for id in sync_dict:
		if sync_dict[id]:
			send_server_rpc_to_one_player_unreliable(id, server_cmd, args)

func add_to_sync_with():
	pass

##
## the following 3 functions handle all direct calls from the client
## the first function is for player commands to the server as a whole
## the second function for the player sending commands to their "representative" on the server
## the last one adds the player to the server / other clients and vice versa
##

remote func parse_client_rpc(client_cmd, args):
	callv(client_cmd, args)

func return_ping_query_unreliable(uuid):
	var caller_id = get_tree().get_rpc_sender_id()
	yield(get_tree().create_timer(0.5),"timeout")
	send_server_rpc_to_one_player_unreliable(caller_id, "conclude_ping_query_unreliable", [uuid])

func return_ping_query_reliable(uuid):
	var caller_id = get_tree().get_rpc_sender_id()
	yield(get_tree().create_timer(0.5),"timeout")
	send_server_rpc_to_one_player(caller_id, "conclude_ping_query_reliable", [uuid])
