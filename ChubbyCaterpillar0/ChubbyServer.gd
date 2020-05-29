extends Node

# You fools. this is actually the client code!

# TODO: 
# reduce hard_coding. Create port, ip, map, character selectors
# modify sendplayerrpc to only allow for the player to send its own phantom commands
#

# EXPLANATION:
# basically a central server and a client side middle server
# the client player send their movement instructions through rpc_unreliable_id
# and other instructions through reliable
# Instead of individual physics functions per player, make single_physics_frame functions and
# handle all of those through this file/node (chubbycaterpillar's server)
# For simplicity's sake



# hard coded. please change
const DEFAULT_PORT = 3342
onready var Interpolator = get_node("Interpolator")
var uuid_generator = preload("res://server_resources/uuid_generator.tscn")
var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
var ChubbyCharacter0 = preload("res://character/game_characters/ChubbyCharacter0.tscn")
var ChubbyCharacter1 = preload("res://character/experimental_character/ChubbyCharacter_experimental_0.tscn")
var map = preload("res://maps/Map0.tscn")
var TimeQueue = preload("res://character/base_character/TimeQueue.tscn")

# int: client_id sex
# dictionary int-chubbycharacter: tracks all connected players
# string: my_type the class of the character we control
# Node2d: client_uuid_generator a utility node which makes uuids...helps catalogue objects/timedeffects
var client_id 
var players = {}
var my_type = "pubert"
var client_uuid_generator = uuid_generator.instance()

# keeps track of client physics processing speed, used for interpolating server/client position
var client_delta

func _ready():
	start_client()
	client_id = get_tree().get_network_unique_id()
	
	print(client_id)

	add_a_player(client_id, my_type)
	var my_map = map.instance()

	# rpc_id(1, "parse_client_rpc", client_id, "right", []) 
	
	add_child(my_map)
	
	var timequeue = TimeQueue.instance()
	add_child(timequeue)
#	timequeue.init_time_queue(1, 20, ["health", "velocity"])
	
#	rpc_id(1, "print_thing")
	
#	print(get_tree())

# executes the client function specified by the server
# @param server_cmd - client function to call 
# @param args - arguments to pass into the command
remote func parse_server_rpc(server_cmd, args):
	#print("Command [" + server_cmd + "] called from server")

	callv(server_cmd, args)

func say_zx():
	print("I said zx ok?? My name a ", client_id)

# called upon connecting to server, asks for our player's type information in order to construct a replica on server	
func send_blueprint():
	rpc_id(1, "add_player", client_id, my_type)
	print("sending blueprint for ", client_id)

##
## these functions handle sending most player commands to server
##

func send_client_rpc(client_cmd, args):
	rpc_id(1, "parse_client_rpc", client_cmd, args)

func send_client_rpc_unreliable(client_cmd, args):
	rpc_unreliable_id(1, "parse_client_rpc", client_cmd, args)

# allow client to send command to specific player (our own)
func send_player_rpc(id, command, args):
	if id == client_id:
		rpc_id(1, "parse_player_rpc", id, command, args) 

func send_player_rpc_unreliable(id, command, args):
	if id == client_id:
		rpc_unreliable_id(1, "parse_player_rpc", id, command, args) 

func start_client():
	var client = NetworkedMultiplayerENet.new()
	client.create_client("127.0.0.1", DEFAULT_PORT)
	get_tree().set_network_peer(client)
	print("client created")

# adds a character to the local (client) scenetree
# int: id the player's network id
# string: type the player's class
# bool: mine whether or not this is our player
func add_a_player(id, type):
	var player_to_add

	match type:
		"base":
			player_to_add = ChubbyCharacter.instance()
		"pubert":
			player_to_add = ChubbyCharacter0.instance()
		_:
			player_to_add = ChubbyCharacter.instance()
	
	# sets player node's name and id
	player_to_add.set_id(id)
	player_to_add.set_name(str(id))
	
	# sets my player as network master
	if id == client_id:
		player_to_add.set_network_master(id)
	
	# adds player node
	get_node("/root/ChubbyServer").add_child(player_to_add)
	players[id] = player_to_add

func add_other_player(id, type):
	# checks if the "other player" is in fact our client player to avoid duplicating it
	if (id != client_id):
		var other_player
		
		match type:
			"base":
				other_player = ChubbyCharacter.instance()
			_:
				other_player = ChubbyCharacter.instance()
		other_player.set_id(id)
		other_player.set_name(str(id))
		get_node("/root/ChubbyServer").add_child(other_player)
		players[id] = other_player

func remove_other_player(id):
	# Checks if not already removed
	print("Removing player ", id)
	if (players.has(id)):
	#	remove_child(players[id])
	#	players[id].queue_free()
	#	players.erase(id)
		players.erase(id)
		var disconnected_players_phantom = get_node("/root/ChubbyServer/" + str(id))
		remove_child(disconnected_players_phantom)
		disconnected_players_phantom.queue_free()

# general add player
# function not used for now...may come in handy when switching player control
remote func add_random_player(id, type):
	if (!players.has(id)):
		var chubby_character

		match type:
			"base":
				chubby_character = ChubbyCharacter.instance()
			_:
				chubby_character = ChubbyCharacter0.instance()

		chubby_character.set_id(id)
		chubby_character.set_name(str(id))
		
		if (id == client_id):
			chubby_character.set_network_master(id)
		
		get_node("/root/ChubbyServer").add_child(chubby_character)
		players[id] = chubby_character
	

#  
func _physics_process(delta):
	client_delta = delta

# updates position of a player based on recent server info
func parse_updated_player_position_from_server(id, latest_server_position):
	# Interpolates between client position and server position using client_delta, aka physics processing rate, to determine a smooth speed
	Interpolator.interpolate_property(get_node("/root/ChubbyServer/" + str(id)), "position", players[id].get_global_position(), latest_server_position, client_delta, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	Interpolator.start()