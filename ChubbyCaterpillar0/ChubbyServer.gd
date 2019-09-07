extends Node

# You fools. this is actually the client code!

const DEFAULT_PORT = 3342

var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
# hard coded for now
var map = preload("res://maps/Map0.tscn")

func _ready():
	start_client()
	
	var my_chubby_character = ChubbyCharacter.instance()
	my_chubby_character.set_stats(200, 200, 2, Vector2(0,0), get_tree().get_network_unique_id())
	var my_map = map.instance()
	
	add_child(my_map)
	add_child(my_chubby_character)
	
	

func start_client():
	var client = NetworkedMultiplayerENet.new()
	client.create_client("127.0.0.1", DEFAULT_PORT)
	get_tree().set_network_peer(client)
	print("client created")