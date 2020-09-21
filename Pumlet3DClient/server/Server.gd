extends Node

# # # 4e 69 70 68 72 69 61 20 50 75 6d 6c 65 74 20 51 69

## Handles top-level game logic
## Loads maps
## Connects to server
## Utilities for server communication

##
## constants and ENUMs
##

const DEFAULT_PORT = 3342
enum Species {BASE, PUBERT, SQUEEGEE, PUMBITA, JINGLING, SHIMMER, CAPIND, PUMPQUEEN}
enum Sign {TERROR, ERRANT, VULN}
enum Map {PODUNK}

var server_ip = "127.0.0.1"
var client_net = null # the ENet containing the client
var client_id := 0
var players = {} # tracks all connected players
var my_species : int = Species.BASE
var my_team : int = 0
var current_map
var offline = false
var minmap_size = Vector2(1600, 1000)

# -----------------------------------------------------------Functionality Nodes

onready var wap = $WorldAudioPlayer
onready var input_handler = $ClientInputHandler
var uuid_gen = preload("res://common/utils/UUIDGenerator.gd")

##
## Preloaded resources
##

var base_character = preload("res://common/characters/BaseCharacter.tscn")
var base_fauna = preload("res://common/fauna/BaseFauna.tscn")
var podunk = preload("res://common/envs/impl_envs/Podunk.tscn")

# keeps track of client physics processing speed, used for interpolating server/client position
var client_delta = 1.0 / (ProjectSettings.get_setting("physics/common/physics_fps"))

##
## Signals
##

signal minimap_texture_updated(texture, origin)
signal our_player_spawned(our_player_node)
signal player_spawned(player_node)

func _ready():
	connect("our_player_spawned", input_handler, "_on_our_player_spawned")
	current_map = podunk.instance()
	add_child(current_map)
	var player = base_character.instance()
	player.transform.origin = Vector3(0, 40, 0)
	add_child(player)
	emit_signal("our_player_spawned", player)
	spawn_targets(10)
	wap.play()
	start_game_multiplayer()

func _process(delta):
	pass
	#start_ping_query_reliable()

func spawn_targets(num_targets):
	for i in range(num_targets):
		var target = base_fauna.instance()
		target.transform.origin = (
			Vector3(0, 4, 0) + 
			5 * (
				Vector3(cos(2 * PI * float(i) / num_targets), 0, sin(2 * PI * float(i) / num_targets))
			))
		add_child(target)

# ---------------------------------------------------------Client Initialization
func start_game_multiplayer():
	client_net = NetworkedMultiplayerENet.new()
	# compressing data packets -> big speed
	client_net.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_ZSTD)
	start_client()
	# Connect network signals
	client_net.connect("server_disconnected", self, "_on_disconnect")
	client_net.connect("connection_failed", self, "_on_disconnect")
	client_net.connect("connection_succeeded", self, "_on_connection_succeeded")
	
	# Adds our player
	#add_a_player(client_id, my_team, my_team, {})

func start_client():
	# Start connection
	client_net.create_client(server_ip, DEFAULT_PORT)
	# Set client as our network peer
	get_tree().set_network_peer(client_net)
	client_id = get_tree().get_network_unique_id()
	print(client_id)
	print("client created")

# executes the client function specified by the server
# @param server_cmd - client function to call 
# @param args - arguments to pass into the command
remote func parse_server_rpc(server_cmd, args):
	#print("Command [" + server_cmd + "] called from server")
	callv(server_cmd, args)

# -----------------------------------------------------------Connected Functions

# Called on ongoing or attempted connection failure
func _on_disconnect():
	offline = true
	print("server disconnected")

# Called when a connection attempt succeeds
func _on_connection_succeeded():
	offline = false

func add_a_player(id, species, team: int, initialization_values):
	var player_to_add
	
	match species:
		Species.BASE:
			player_to_add = base_character.instance()
		_:
			player_to_add = base_character.instance()
	
	# sets player attributes
	player_to_add.set_id(id)
	player_to_add.set_name(str(id))
	player_to_add.team = team
	player_to_add.set_team(team)
	player_to_add.position = player_to_add.respawn_position
	player_to_add.set_initialization_values(initialization_values)
	
	# sets my player as network master
	if id == client_id:
		player_to_add.set_network_master(id)
		
		# camera follow
		print("Our character created")
		var camera = get_node("Camera2D")
		#camera.make_current()
		remove_child(camera)
		player_to_add.add_child(camera)
		
		emit_signal("player_spawned")
	
	# adds player node
	add_child(player_to_add)
	
	players[id] = player_to_add



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

# -----------------------------------------------------------------------Utility
var ping_avg_reliable = 0
var ping_avg_unreliable = 0
var new_ping_weight = 0.2
var ping_avg_timestamp_dict = {}

func start_ping_query_unreliable():
	var uuid = uuid_gen.v4()
	ping_avg_timestamp_dict[uuid] = OS.get_ticks_usec()
	send_client_rpc_unreliable("return_ping_query_unreliable", [uuid])

func start_ping_query_reliable():
	var uuid = uuid_gen.v4()
	ping_avg_timestamp_dict[uuid] = OS.get_ticks_usec()
	send_client_rpc_unreliable("return_ping_query_reliable", [uuid])

func conclude_ping_query_unreliable(uuid):
	var ping_time = (OS.get_ticks_usec() - ping_avg_timestamp_dict[uuid])
	print(ping_time)
	if ping_avg_unreliable == 0:
		ping_avg_unreliable = ping_time
	else:
		ping_avg_unreliable = ((
				ping_avg_unreliable + 
				new_ping_weight * ping_time) / 
				(1 + new_ping_weight))
	ping_avg_timestamp_dict.erase(uuid)

func conclude_ping_query_reliable(uuid):
	var ping_time = (OS.get_ticks_usec() - ping_avg_timestamp_dict[uuid])
	print(ping_time)
	if ping_avg_reliable == 0:
		ping_avg_reliable = ping_time
	else:
		ping_avg_reliable = ((
				ping_avg_reliable + 
				new_ping_weight * ping_time) / 
				(1 + new_ping_weight))
	ping_avg_timestamp_dict.erase(uuid)

func send_client_rpc(client_cmd, args):
	rpc_id(1, "parse_client_rpc", client_cmd, args)

func send_client_rpc_unreliable(client_cmd, args):
	rpc_unreliable_id(1, "parse_client_rpc", client_cmd, args)

# sends our in-game commands to the server
func send_player_rpc(id, command, args):
	# prevents cheating by faking commands from other players
	if id == client_id:
		rpc_id(1, "parse_player_rpc", id, command, args) 

func send_player_rpc_unreliable(id, command, args):
	# prevents cheating by faking commands from other players
	if id == client_id:
		rpc_unreliable_id(1, "parse_player_rpc", id, command, args)
