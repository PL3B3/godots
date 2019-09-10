extends Node

# You fools. this is actually the client code!

# TODO: 
# reduce hard_coding. Create port, ip, map, character selectors
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
var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
var map = preload("res://maps/Map0.tscn")

var client_id 
var my_player_id
var players = {}
var my_type = "base"

func _ready():
	start_client()
	client_id = get_tree().get_network_unique_id()
	
	print(client_id)

	add_my_player(client_id, my_type)
	var my_map = map.instance()

	rpc_id(1, "parse_client_rpc", client_id, "right", []) 
	
	add_child(my_map)
	
#	rpc_id(1, "print_thing")
	
#	print(get_tree())

remote func say_zx():
	print("I said zx ok?? My name a ", client_id)
	
remote func send_blueprint():
	rpc_id(1, "add_player", client_id, my_type)
	print("sending blueprint for ", client_id)

func send_player_rpc(id, command, args):
	rpc_id(1, "parse_client_rpc", id, command, args) 

func send_player_rpc_unreliable(id, command, args):
	rpc_unreliable_id(1, "parse_client_rpc_unreliable", id, command, args) 

func start_client():
	var client = NetworkedMultiplayerENet.new()
	client.create_client("192.168.174.1", DEFAULT_PORT)
	get_tree().set_network_peer(client)
	print("client created")

# specifically to add my character...special sets it to network_master
func add_my_player(id, type):
	var my_chubby_character = ChubbyCharacter.instance()
	my_chubby_character.set_stats(200, 200, 2, Vector2(0,0), client_id)
	my_chubby_character.set_name(str(client_id))
	my_chubby_character.set_network_master(client_id)
	get_node("/root/ChubbyServer").add_child(my_chubby_character)

func add_player(id, type):
	var player
	
	match type:
		"base":
			player = ChubbyCharacter.instance()
	
	players[id] = player
	
	get_node("/root/ChubbyServer").add_child(player)
	
# client_update and client_update_unreliable are called by their respective rpc functions by the server
#  

#
remote func client_update_unreliable(players_updates_unreliable):
	pass