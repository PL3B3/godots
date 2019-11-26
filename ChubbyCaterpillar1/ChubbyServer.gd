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
onready var Interpolator = get_node("Interpolator")
var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
var ChubbyCharacter0 = preload("res://character/ChubbyCharacter0.tscn")
var map = preload("res://maps/Map0.tscn")
var TimeQueue = preload("res://character/base_character/TimeQueue.tscn")

var client_id 
var my_player_id
var players = {}
var my_type = "pubert"

# keeps track of client physics processing speed, used for interpolating server/client position
var client_delta

func _ready():
	start_client()
	client_id = get_tree().get_network_unique_id()
	
	print(client_id)

	add_my_player(client_id, my_type)
	var my_map = map.instance()

	# rpc_id(1, "parse_client_rpc", client_id, "right", []) 
	
	add_child(my_map)
	
	var timequeue = TimeQueue.instance()
	add_child(timequeue)
	timequeue.init_time_queue(0.1, 20, ["health","velocity","gravity2"])
	
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
	client.create_client("127.0.0.1", DEFAULT_PORT)
	get_tree().set_network_peer(client)
	print("client created")

# specifically to add my character...special sets it to network_master
func add_my_player(id, type):
	var my_chubby_character

	match type:
		"base":
			my_chubby_character = ChubbyCharacter.instance()
		"pubert":
			my_chubby_character = ChubbyCharacter0.instance()
		_:
			my_chubby_character = ChubbyCharacter.instance()

	my_chubby_character.set_id(id)
	my_chubby_character.set_name(str(id))
	my_chubby_character.set_network_master(id)
	get_node("/root/ChubbyServer").add_child(my_chubby_character)
	players[id] = my_chubby_character

remote func add_other_player(id, type):
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

remote func remove_other_player(id):
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
remote func add_random_player(id, type):
	if (!players.has(id)):
		var chubby_character

		match type:
			"base":
				chubby_character = ChubbyCharacter.instance()
			_:
				chubby_character = ChubbyCharacter.instance()

		chubby_character.set_id(id)
		chubby_character.set_name(str(id))
		
		if (id == client_id):
			chubby_character.set_network_master(id)
		
		get_node("/root/ChubbyServer").add_child(chubby_character)
		players[id] = chubby_character
	
# client_update and client_update_unreliable are called by their respective rpc functions by the server
#  

func _physics_process(delta):
	client_delta = delta
#
remote func parse_updated_player_position_from_server_unreliable(id, latest_server_position):
	# Interpolates between client position and server position using client_delta, aka physics processing rate, to determine a smooth speed
	Interpolator.interpolate_property(get_node("/root/ChubbyServer/" + str(id)), "position", players[id].get_global_position(), latest_server_position, client_delta, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	Interpolator.start()
