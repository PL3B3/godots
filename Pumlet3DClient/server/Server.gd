extends "res://common/server/BaseServer.gd"

# --------------4e 69 70 68 72 69 61 20 50 75 6d 6c 65 74 20 51 69--------------

## Handles top-level game logic
## Loads maps
## Connects to server
## Utilities for server communication

# -----------------------------------------------------------Constants and Enums

var server_ip = "127.0.0.1"
var client_net = null # the ENet containing the client

var our_species : int = Species.BASE
var our_team : int = 0
var our_player

var connected = false

# -----------------------------------------------------------Functionality Nodes

onready var wap = $WorldAudioPlayer
onready var input_handler = $ClientInputHandler


# keeps track of client physics processing speed, used for interpolating server/client position
var client_delta = 1.0 / (ProjectSettings.get_setting("physics/common/physics_fps"))

##
## Signals
##

signal minimap_texture_updated(texture, origin)
signal our_player_spawned(our_player_node)
signal other_player_spawned(other_player_node)

func _ready():
	# resource node initialization
	
	base_character = load("res://characters/Character.tscn")
	
	# connections
	connect("our_player_spawned", input_handler, "_on_our_player_spawned")
	
	
#	start_game_offline()
	start_game_multiplayer()

# ---------------------------------------------------------Client Initialization
func start_game_offline():
	add_map()
	add_our_player()
	wap.play()

func start_game_multiplayer():
	add_map()
	start_client()
	#spawn_targets(10)
	wap.play()

func start_client():
	client_net = NetworkedMultiplayerENet.new()
	# compressing data packets -> big speed
	client_net.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_ZSTD)
	# Start connection
	client_net.create_client(server_ip, DEFAULT_PORT)
	# Set client as our network peer
	get_tree().set_network_peer(client_net)
	network_id = get_tree().get_network_unique_id()
	print("Client #%d created" % network_id)
	# Connect network signals
	client_net.connect("server_disconnected", self, "_on_disconnect")
	client_net.connect("connection_failed", self, "_on_disconnect")
	client_net.connect("connection_succeeded", self, "_on_connection_succeeded")

func start_client_setup():
	send_client_rpc("setup_client", [our_species, our_team])


# -------------------------------------------------------RPC callers / recievers 
remote func parse_server_rpc(server_cmd, args):
	if self.has_method(server_cmd):
		callv(server_cmd, args)
	else:
		print("Server called nonexistent method %s" % server_cmd)

func send_client_rpc(client_cmd, args):
	rpc_id(1, "parse_client_rpc", client_cmd, args)

func send_client_rpc_unreliable(client_cmd, args):
	rpc_unreliable_id(1, "parse_client_rpc", client_cmd, args)

# sends our in-game commands to the server
func send_player_rpc(command, args):
	rpc_id(1, "parse_player_rpc", command, args) 

func send_player_rpc_unreliable(command, args):
	rpc_unreliable_id(1, "parse_player_rpc", command, args)

# -----------------------------------------------------------Connected Functions

# Called on ongoing or attempted connection failure
func _on_disconnect():
	connected = false
	print("server disconnected")

# Called when a connection attempt succeeds
func _on_connection_succeeded():
	connected = true
	start_client_setup()

func _periodic(timer_period):
#	start_ping_query_unreliable()
#	ping_unreliable([1, "thing", 0])
	print(ping_avg)

# ---------------------------------------------------------------Player Handling

func add_our_player():
	var our_player_node = initialize_and_add_player(
		network_id, 
		our_species, 
		our_team, 
		team_respawn_positions[our_team],
		[])
	
	set_network_master(network_id)
	
	our_player = our_player_node
	
	emit_signal("our_player_spawned", our_player_node)

func add_other_player(id, species, team: int, origin: Vector3, initialization_values):
	var player_to_add = initialize_and_add_player(
		id, 
		species, 
		team, 
		origin,
		initialization_values)
	
	emit_signal("other_player_spawned", player_to_add)


# -----------------------------------------------------------------------Syncing
var ping_interp_threshold = 14000 # below this, projection is unecessary
var own_player_interp_speed = 0.1
func update_own_player_origin(server_origin):
	var current_origin = our_player.transform.origin
	var displacement = our_player.get_displacement_usecs_ago(
		max(
			ping_avg, 
			1.2 * (
				OS.get_ticks_usec() - 
				our_player.last_queue_add_timestamp)))
	print(displacement)
	var projected_origin = server_origin + displacement
	print(
		"Server origin at %s, current origin at %s, difference is %3.1f large" % 
		[
			server_origin, 
			current_origin, 
			(server_origin - current_origin).length()])
	
	our_player.transform.origin = (
		our_player.transform.origin.linear_interpolate(
			projected_origin,
			0.1))

func call_node_method(node_name: String, method_name: String, args) -> void:
	var node_to_call = get_node("/root/Server/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_call):
		# call the method
		node_to_call.callv(method_name, args)
