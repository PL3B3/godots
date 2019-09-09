extends Node

# You fools. this is actually the client code!

const DEFAULT_PORT = 3342

var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
# hard coded for now
var map = preload("res://maps/Map0.tscn")

onready var client_id = get_tree().get_network_unique_id()
var players = {}
var my_type = "base"

func _ready():
	start_client()
	
	add_my_player(client_id, my_type)
	var my_map = map.instance()
	
	add_child(my_map)
	
#	rpc_id(1, "print_thing")
	
#	print(get_tree())

remote func say_zx():
	print("I said zx ok?? My name a ", client_id)
	
remote func send_blueprint():
	rpc_id(1, "add_player", client_id, my_type)
	print("sending blueprint for ", client_id)

func start_client():
	var client = NetworkedMultiplayerENet.new()
	client.create_client("127.0.0.1", DEFAULT_PORT)
	get_tree().set_network_peer(client)
	print("client created")

# specifically to add my character...special sets it to network_master
func add_my_player(id, type):
	var my_chubby_character = ChubbyCharacter.instance()
	my_chubby_character.set_stats(200, 200, 2, Vector2(0,0), client_id)
	my_chubby_character.set_name(str(client_id))
	add_child(my_chubby_character)
	my_chubby_character.set_network_master(client_id)

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