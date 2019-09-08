extends Node

# You fools. this is actually the client code!

const DEFAULT_PORT = 3342

var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
# hard coded for now
var map = preload("res://maps/Map0.tscn")

var client_id
var players = {}
var my_type = "base"

func _ready():
	start_client()
	
	client_id = get_tree().get_network_unique_id()
	
	var my_chubby_character = ChubbyCharacter.instance()
	my_chubby_character.set_stats(200, 200, 2, Vector2(0,0), client_id)
	var my_map = map.instance()
	
	add_child(my_map)
	add_child(my_chubby_character)
	
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

func add_player(id, type):
	var player
	
	match type:
		"base":
			player = ChubbyCharacter.instance()
	
	players[id] = player
	
	get_node("/root/ChubbyServer").add_child(player)
	