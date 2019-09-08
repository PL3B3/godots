extends Node

const DEFAULT_PORT = 3342
const MAX_PLAYERS = 8

var players = {}
var ChubbyPhantom = preload("res://ChubbyPhantom.tscn")
var ChubbyPhantom0 = preload("res://ChubbyPhantom0.tscn")
var map = preload("res://maps/Map0.tscn")
var physics_processing = false

func _ready():
	
	
	var server_map = map.instance()
#	var nai = ChubbyPhantom.instance()
	start_server()

	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	add_child(server_map)
#	get_node("/root/ChubbyServer").add_child(nai)
	
#	var client_0 = NetworkedMultiplayerENet.new()
#	client_0.create_client('127.0.0.1', DEFAULT_PORT)
#	get_tree().set_network_peer(client_0)

remote func print_thing():
	print("i printed a boi")

func start_server():
	var server = NetworkedMultiplayerENet.new()
	
	# compressing data packets -> big speed
	# server.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_ZLIB)
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
	rpc_id(id, "send_blueprint")
	rpc_id(id, "say_zx")
	print(get_tree().get_network_connected_peers())
	
func _player_disconnected(id):
	players.erase(id)
	
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

# this function is called upon player_connected, which calls the player to tell this function its id and class type
remote func add_player(id, type):
	var player_phantom
	
	print("Constructing player with id ", id, " and type ", type)

	# construct an instance of a ChubbyPhantom or heir scene using the type provided 
	match type:
		"base":
			print("creating base character")
			player_phantom = ChubbyPhantom.instance()
		"0":
			player_phantom = ChubbyPhantom0.instance()
		_:
			print("creating other character")
			player_phantom = ChubbyPhantom.instance()
	
	player_phantom.set_name(str(id))
	players[id] = player_phantom

	get_node("/root/ChubbyServer").add_child(player_phantom)
	
	physics_processing = true

# function called by client rpc, which executes a method of that client's representative ChubbyPhantom here on the server
remote func parse_client_rpc(id, command, args):
	players[id].callv(command, args)

# TODO: do multithreading later for efficiency. players should be a dict of id: {ChubbyPhantom, thread}
func _physics_process(delta):
	if physics_processing:
		for id in players:
			players[id].physics_single_execute(delta)