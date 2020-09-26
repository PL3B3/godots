extends "res://common/server/BaseServer.gd"

# --------------4e 69 70 68 72 69 61 20 50 75 6d 6c 65 74 20 51 69--------------

## Handles top-level game logic
## Loads maps
## Connects to server
## Utilities for server communication

# -----------------------------------------------------------Constants and Enums

var server_ip = "127.0.0.1"
var client_net = null # the ENet containing the client
var simulated_ping = 0.06

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
	spawn_targets(5)
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
	yield(get_tree().create_timer(simulated_ping), "timeout")
	rpc_id(1, "parse_player_rpc", command, args) 

func send_player_rpc_unreliable(command, args):
	yield(get_tree().create_timer(simulated_ping), "timeout")
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
#	if connected:
#		ping([1, "thing", 0])
#		print("Ping average is %s" % ping_avg)
	pass

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
	
	our_player.camera.current = true
	our_player.physics_enabled = true
	our_player.is_own_player = true
	
	emit_signal("our_player_spawned", our_player_node)

func add_other_player(id, species, team: int, origin: Vector3, initialization_values):
	var player_to_add = initialize_and_add_player(
		id, 
		species, 
		team, 
		origin,
		initialization_values)
	
#	player_to_add.physics_enabled = true
	
	emit_signal("other_player_spawned", player_to_add)


# -----------------------------------------------------------------------Syncing
var ping_interp_threshold = 14000 # below this, projection is unecessary
var own_player_interp_speed = 0.34
var counter = 0
var origin_jump_limit_absolute = 1
var no_sync_threshold = 0.005
var last_sequence_number_processed = -1
var avg_error_size = 0
func update_own_player_origin(server_origin, sequence_number):
	if not sequence_number > last_sequence_number_processed:
		return
	
	last_sequence_number_processed = sequence_number
	var current_origin = our_player.transform.origin
#	if current_origin.distance_to(server_origin) < no_sync_threshold:
#		return
	var displacement = our_player.motion_time_queue.replay_since_tick(sequence_number)
#	var displacement = our_player.get_cumulative_movement_usecs_ago(ping_avg + 1000000 * simulated_ping)
	var projected_origin = server_origin + displacement
	var error = projected_origin - current_origin
#	print(our_player.motion_time_queue.ticks_since_start - sequence_number)
	if counter % 100 == 0:
#		print(our_player.motion_time_queue.ticks_since_start - sequence_number)
		print(avg_error_size)
#		print(
#			"Projected %s \n Current %s \n Server %s \n Displacement %s \n Diff 4.2f %s" % 
#			[
#				projected_origin, 
#				current_origin, 
#				server_origin,
#				displacement,
#				(projected_origin - current_origin).length()])
#		print(our_player.motion_time_queue.queue)
	counter += 1
	
	var error_size = error.length()
	avg_error_size = (avg_error_size + 0.3 * error_size) / 1.3
	
	if error_size > origin_jump_limit_absolute:
		our_player.transform.origin = projected_origin
	elif error_size < no_sync_threshold:
		return
	else:
		our_player.move_and_collide(
			own_player_interp_speed * 
			(projected_origin - current_origin))

var other_player_interp_speed = 0.16
var other_player_origin_target_dict = {}
func interpolate_player_origin(player_id, new_origin):
	other_player_origin_target_dict[player_id] = new_origin


func call_node_method(node_name: String, method_name: String, args) -> void:
	var node_to_call = get_node("/root/Server/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_call):
		# call the method
		node_to_call.callv(method_name, args)

func _physics_process(delta):
	for player_id in other_player_origin_target_dict:
		var player_to_update = players.get(player_id)
		if is_instance_valid(player_to_update):
			var target_origin = other_player_origin_target_dict[player_id]
			var current_origin = player_to_update.transform.origin
			if (target_origin - current_origin).length() > no_sync_threshold:
				player_to_update.transform.origin = (
					player_to_update.transform.origin.linear_interpolate(
						target_origin, 
						other_player_interp_speed))
#				player_to_update.move_and_collide(
#					other_player_interp_speed * 
#					(target_origin - current_origin))
