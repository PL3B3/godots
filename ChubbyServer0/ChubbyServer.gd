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

var uuid_generator = preload("res://server_resources/uuid_generator.tscn")
var ChubbyPhantom = preload("res://character/base_character/ChubbyPhantom.tscn")
var ChubbyPhantom0 = preload("res://character/game_characters/ChubbyPhantom0.tscn")
var map = preload("res://maps/Map0.tscn")
var map2 = preload("res://maps/Map2.tscn")

var physics_processing = false
var players = {}
var server_uuid_generator = uuid_generator.instance()

func _ready():
	var server_map = map2.instance()
	
	start_server()

	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	add_child(server_map)
	add_child(server_uuid_generator)

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
	rpc_id(id, "parse_server_rpc", "send_blueprint", [])
	# rpc_id(id, "parse"say_zx")

	print(get_tree().get_network_connected_peers())
	
func _player_disconnected(id):
	players.erase(id)
	print("Player " + str(id) + " disconnected")
	var disconnected_players_phantom = get_node("/root/ChubbyServer/" + str(id))
	remove_child(disconnected_players_phantom)
	disconnected_players_phantom.queue_free()
	send_server_rpc_to_all_players("remove_other_player", [id])

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

##
## the following 3 functions handle all direct calls from the client
## the first function is for player commands to the server as a whole
## the second function for the player sending commands to their "representative" on the server
## the last one adds the player to the server / other clients and vice versa
##

remote func parse_client_rpc(client_cmd, args):
	callv(client_cmd, args)

# tcp function called by client rpc, which executes a method of that client's representative ChubbyPhantom here on the server
# this method may be movement OR an ability...handling both in one function for simplicity
# todo whitelist / blacklist for which commands are acceptable...
remote func parse_player_rpc(player_id, method_name, args) -> void:
	var caller_id = get_tree().get_rpc_sender_id()
	
	#print("Player ", caller_id, " called function ", method_name)
	
	# stops non-player peers from controlling that player
	if (str(caller_id) == str(player_id)):
		var ability_num = ability_conversions.get(method_name)
		var player_to_call = players[player_id]
		# if this is an actual ability, not just movement, 
		if ability_num != null:
			if !player_to_call.ability_usable[ability_num]: # ability isn't usable
				# so end the function here, doing nothing
				return		
		
		# if we reach this point, the method is either a movement or a legitimate ability call
		
		# we call it
		player_to_call.callv("use_ability_and_start_cooldown", [method_name, args])
		
		# sends this command to other clients
		for id in players:
			if id != player_id:
				call_player_method_on_client(id, player_id, method_name, args)
#				send_server_rpc_to_one_player(id, "call_player_method", [player_id, method_name, args])

# Calls a method of player_id's representation on client_id
func call_player_method_on_client(client_id, player_id: int, method_name: String, args):
	send_server_rpc_to_one_player(client_id, "call_node_method", [str(player_id), method_name, args])
	
func update_attribute(attribute_name: String, new_value, node_name: String) -> void:
	send_server_rpc_to_all_players_unreliable("update_node_attribute", [node_name, attribute_name, new_value])

func set_attribute(attribute_name: String, new_value, node_name: String) -> void:
	send_server_rpc_to_all_players_unreliable("set_node_attribute", [node_name, attribute_name, new_value])

# call a method on all this phantom's client instances
func call_player_method_on_all_clients(method_name: String, args, node_name: String) -> void:
	send_server_rpc_to_all_players("call_node_method", [node_name, method_name, args])


# this function is called upon player_connected, which calls the player to tell this function its id and class type
remote func add_player(type, team):
	var id = get_tree().get_rpc_sender_id()
	
	var player_phantom
	
	# @d
	print("Constructing player with id ", id, " and type ", type)

	# construct an instance of a ChubbyPhantom or heir scene using the type provided 
	match type:
		"base":
			print("creating base character")
			player_phantom = ChubbyPhantom.instance()
			player_phantom.type = "base"
		"pubert":
			player_phantom = ChubbyPhantom0.instance()
			player_phantom.type = "pubert"
		_:
			print("creating other character")
			player_phantom = ChubbyPhantom.instance()
			player_phantom.type = "base"
	
	# set player node name
	player_phantom.set_name(str(id))
	
	# sets player team
	player_phantom.team = team
	player_phantom.set_team(team)

	# add player to the dictionary containing all player representations
	players[id] = player_phantom

	# add player to scene tree, specifically ChubbyServer. MUST BE SAME SCENE STRUCTURE AS CLIENT. ADD ALL CLIENT PLAYERS TO root/chubbyserver TOO
	get_node("/root/ChubbyServer").add_child(player_phantom)
	
	# @d
	print("These are the children ", get_children())

	# set new player's id, so that it has an internal reference to it
	players[id].set_id(id)
	

	# turn on the server's physics simulation FOR THIS PLAYER SPECIFICALLY if not already on
	#players[id].physics_processing = true

	# ensures all other clients have a copy of this player and vice versa
	add_new_player_to_current_clients_and_old_players_to_new_client(id, type, team)

# for security purposes
func generate_player_id():
	pass

# when a new player is added, it should be replicated in other clients' scenetrees
# also, existing players must be added to the new client
func add_new_player_to_current_clients_and_old_players_to_new_client(new_player_id, new_player_type, new_player_team):
	for player_id in players:
		# avoids redundantly adding our new player to its own client
		if (player_id != new_player_id):
			# add new player to existing clients
			send_server_rpc_to_one_player(player_id, "add_a_player", [new_player_id, new_player_type, new_player_team])
			# add existing players to new client
			send_server_rpc_to_one_player(new_player_id, "add_a_player", [player_id, players[player_id].type, players[player_id].team])

# sends another client's commands in a dictionary
func send_other_client_commands(id, other_id, their_command):
	pass


# TODO: do multithreading later for efficiency. players should be a dict of id: {ChubbyPhantom, thread}

func _physics_process(delta):
	if Input.is_action_pressed("ui_left"):
		$Camera2D.position += Vector2(-10,0)
	if Input.is_action_pressed("ui_right"):
		$Camera2D.position += Vector2(10,0)
	if Input.is_action_pressed("ui_up"):
		$Camera2D.position += Vector2(0,-10)
	if Input.is_action_pressed("ui_down"):
		$Camera2D.position += Vector2(0,10)
	"""
	for id in players:
		if (players[id].physics_processing):
			players[id].physics_single_execute(delta)
			send_updated_player_position_to_client_unreliable(id, players[id].get_global_position())
	"""
# Sends integrity-sensitive updates like health changes to each client for them to change
func send_updated_player_info_to_all_clients(id, info):
	rpc("parse_updated_player_info_from_server", id, info)
