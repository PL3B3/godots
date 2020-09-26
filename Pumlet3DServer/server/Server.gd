extends "res://common/server/BaseServer.gd"

##
## This is the dedicated server node
##

# ---------------------------------------------------------------------Constants
const MAX_PLAYERS = 12

var cam_focus_counter = 0
var physics_processing = false

var simulated_ping = 1

func _ready():
	# Load game nodes
	base_character = load("res://characters/Character.tscn")
	server_delta = 1.0 / (ProjectSettings.get_setting("physics/common/physics_fps"))
	
	start_game_multiplayer()
	
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
#	test()

func test():
	var meb = add_player(1993, 0, 0)
	var niph = add_player(3342, 0, 1)
	niph.transform.origin = meb.get_global_transform().origin + Vector3(3, 0, 0)

# ---------------------------------------------------------Server Initialization
func start_game_multiplayer():
	add_map()
	start_server()

func start_server():
	var server = NetworkedMultiplayerENet.new()
	
	# compressing data packets -> big speed
	server.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_ZSTD)

	var err = server.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if not err == OK:
		# if another server is running, this will execute
		print("server creation failed")
		# printerr("Can't host, port already in use")
		return
	
	network_id = 1
	
	get_tree().set_network_peer(server)
	print("Server started, waiting for players")
# ---------------------------------------------------------------Player Handling
func add_to_sync_with():
	pass

func add_player(id, species, team):
	var player_phantom = initialize_and_add_player(
		id,
		species, 
		team, 
		team_respawn_positions[team], 
		[])
	
	player_phantom.connect("send_origin_update_to_my_client", self, "update_player_origin", [id])
	player_phantom.camera.current = true
	
	# ensures all other clients have a copy of this player and vice versa
	add_new_player_to_current_clients_and_old_players_to_new_client(id, species, team)
	
	return player_phantom

func add_new_player_to_current_clients_and_old_players_to_new_client(new_player_id, new_player_species, new_player_team):
	var new_player = players[new_player_id]
	for player_id in players:
		# avoids redundantly adding our new player to its own client
		if (player_id != new_player_id):
			var other_player = players[player_id]
			# add new player to existing client
			send_server_rpc_to_one_player(
				player_id,
				"add_other_player",
				[
					new_player_id,
					new_player_species,
					new_player_team,
					team_respawn_positions[new_player_team],
					new_player.get_initialization_values()])
			
			# add new player to existing player sync list on server
			other_player.add_player_to_sync_dict(new_player_id)
			
			# add existing player to new client
			send_server_rpc_to_one_player(
				new_player_id,
				"add_other_player",
				[
					player_id,
					other_player.species,
					other_player.team,
					other_player.transform.origin,
					other_player.get_initialization_values()])
			
			# add existing player to sync list on server
			new_player.add_player_to_sync_dict(player_id)

# -----------------------------------------------------------Connected Functions

func _player_connected(id):
	print("Player with id ", id, " connected")
	print(get_tree().get_network_connected_peers())

func _player_disconnected(id):
	remove_player(id)
	send_server_rpc_to_all_players("remove_player", [id])

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

# -------------------------------------------------------RPC callers / recievers 

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
	
func send_server_rpc_to_specified_players(sync_dict, server_cmd, args):
	for id in sync_dict:
		if sync_dict[id]:
			send_server_rpc_to_one_player(id, server_cmd, args)
	
func send_server_rpc_to_specified_players_unreliable(sync_dict, server_cmd, args):
	for id in sync_dict:
		if sync_dict[id]:
			send_server_rpc_to_one_player_unreliable(id, server_cmd, args)

remote func parse_client_rpc(client_cmd, args):
	if self.has_method(client_cmd):
		callv(client_cmd, args)
		print("Command %s called with args %s" % [client_cmd, args])
	else:
		print("Client %s called nonexistent method %s" % [get_tree().get_rpc_sender_id(), client_cmd])

remote func parse_player_rpc(method_name, args) -> void:
	var player_id = get_tree().get_rpc_sender_id()
	
	var player_to_call = players.get(player_id)
	if not player_to_call == null:
		match method_name:
			"set_direction":
				send_server_rpc_to_one_player_unreliable(
					player_id,
					"update_own_player_origin",
					[
						players[player_id].transform.origin,
						args[1]])
#				print(args[1])
#				print("calling set direction with args %s" % args[0])
				player_to_call.callv(method_name, [args[0]])
			_:
				player_to_call.callv(method_name, args)
				for id in players:
					if id != player_id:
						call_player_method_on_client(id, player_id, method_name, args)


# -----------------------------------------------------------------------Utility

func call_player_method_on_client(client_id, player_id: int, method_name: String, args):
	send_server_rpc_to_one_player(client_id, "call_node_method", [str(player_id), method_name, args])

func return_ping_query_unreliable(uuid):
	var caller_id = get_tree().get_rpc_sender_id()
	yield(get_tree().create_timer(0.5),"timeout")
	send_server_rpc_to_one_player_unreliable(caller_id, "conclude_ping_query_unreliable", [uuid])

func return_ping_query_reliable(uuid):
	var caller_id = get_tree().get_rpc_sender_id()
	yield(get_tree().create_timer(0.5),"timeout")
	send_server_rpc_to_one_player(caller_id, "conclude_ping_query_reliable", [uuid])

# ------------------------------------------------------------------Client Setup

func setup_client(client_species, client_team):
	var caller_id = get_tree().get_rpc_sender_id()
	add_player(caller_id, client_species, client_team)
	send_server_rpc_to_one_player(caller_id, "add_our_player", [])

# -------------------------------------------------------------Server Monitoring

func _input(event):
	if event.is_action_pressed("ui_focus_next") and not players.empty():
		cam_focus_counter += 1
		var players_key_array = players.keys()
		var index = players_key_array[(
			cam_focus_counter % 
			players_key_array.size())]
		players[index].camera.current = true

# ----------------------------------------------------------------Player Syncing

func update_player_origin(player_to_update: int, new_origin: Vector3, client_to_update_on: int):
	send_server_rpc_to_one_player_unreliable(client_to_update_on, "interpolate_player_origin", [player_to_update, new_origin])

func update_player_velocity(player_to_update: int, new_origin: Vector3, client_to_update_on: int):
	pass
