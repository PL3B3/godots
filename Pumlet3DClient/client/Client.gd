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
var my_type := "pubert"
var my_team : int
var current_map
var offline = false
var minmap_size = Vector2(1600, 1000)

##
## Preloaded resources
##

var base_character = preload("res://characters/base/BaseCharacter.tscn")
var base_fauna = preload("res://fauna/BaseFauna.tscn")
var base_env = preload("res://envs/base/BaseEnv.tscn")
var podunk = preload("res://envs/impl_envs/Podunk.tscn")

# keeps track of client physics processing speed, used for interpolating server/client position
var client_delta = 1.0 / (ProjectSettings.get_setting("physics/common/physics_fps"))

##
## Signals
##

signal minimap_texture_updated(texture, origin)
signal player_spawned()

func _ready():
	current_map = podunk.instance()
	add_child(current_map)
	var player = base_character.instance()
	player.transform.origin = Vector3(0, 40, 0)
	add_child(player)
	var target = base_fauna.instance()
	target.transform.origin = Vector3(0, 14, 0)
	add_child(target)
	#$SelectionInput.connect("text_entered", self, "process_selection_input")

func process_selection_input(selection: String):
	var split_selection = selection.split(",", false)
	offline = bool(int(split_selection[0]))
	my_team = int(split_selection[1])
	if split_selection[2] == "0":
		my_type = "pubert"
	else:
		my_type = "squeegee"
	server_ip = split_selection[3]
	if offline:
		start_game_offline()
	else:
		start_game_multiplayer()
	$SelectionInput.queue_free()

"""
func _unhandled_key_input(event):
	# Debug stuff
	if event is InputEventKey && event.pressed:
		if event.scancode == KEY_T:
			if not offline:
				print(str(client_net.get_connection_status()))
			elif client_net != null && client_net.get_connection_status() != 1: # client_net exists and isn't attempting connection
				reconnect()
"""

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
	add_a_player(client_id, my_type, my_team, {})
	
	# Add map and do initial processing for minimap
	add_child(current_map)
	tilemap_to_tex(current_map.get_node("TileMap"))

func start_game_offline():
	$SelectionInput.queue_free()
	add_a_player(client_id, my_type, my_team, {})
	add_child(current_map)
	tilemap_to_tex(current_map.get_node("TileMap"))
	#$MinMapBoi.texture = tilemap_to_tex(current_map.get_node("TileMap"))
	#$MinMapRenderer.set_size(current_map.get_node("TileMap").get_used_rect().size)
	#$MinMapBoi.set_scale(Vector2(0.13, 0.13))
	#$MinMapBoi.texture = tilemap_to_tex(current_map.get_node("TileMap"))


func align_viewport_to_tilemap(tmap: TileMap, v_port: Viewport) -> Vector2:
	var trect = tmap.get_used_rect()
	
	# Align top left of viewport and tilemap
	var tf = v_port.get_canvas_transform()
	var origin = tmap.map_to_world(trect.position)
	tf.origin = -(origin)
	v_port.set_canvas_transform(tf)
	
	# Expand viewport to see entire tilemap
	v_port.set_size(tmap.map_to_world(trect.size))
	
	return origin

# Uses Viewport MinMapRenderer to render snapshot encompassing given tilemap
func tilemap_to_tex(tmap: TileMap) -> Texture:
	# Temporary viewport to render tilemap
	var mnmapr = $MinMapRenderer
	
	# Delete previous map instance
	if mnmapr.has_node("map_render_target"):
		mnmapr.get_node("map_render_target").queue_free()
	
	# Add map to render
	var tmap_dupe = tmap.duplicate()
	tmap_dupe.set_name("map_render_target")
	mnmapr.add_child(tmap_dupe)
	
	# Alignment, rect_origin is the real world coordinates of map origin
	var rect_origin = align_viewport_to_tilemap(tmap_dupe, mnmapr)
	
	# Get one frame of texture
	mnmapr.set_update_mode(Viewport.UPDATE_ONCE)
	var tex = mnmapr.get_texture()
	
	# For minimap
	emit_signal("minimap_texture_updated", tex, rect_origin)
	
	return tex

func start_client():
	# Start connection
	client_net.create_client(server_ip, DEFAULT_PORT)
	# Set client as our network peer
	get_tree().set_network_peer(client_net)
	client_id = get_tree().get_network_unique_id()
	print(client_id)
	print("client created")

func reconnect():
	# Close and retry connection
	client_net.close_connection()
	client_net.create_client(server_ip, DEFAULT_PORT)
	# Force reset network peer to avoid horrendous reconnection issue
	# See https://github.com/godotengine/godot/issues/34676
	get_tree().set_network_peer(null)
	get_tree().set_network_peer(client_net)
	
	# Save old client id
	var old_client_id = client_id
	# Update client_id
	client_id = get_tree().get_network_unique_id()
	# Find our player with old client_id
	var our_player = players[old_client_id]
	# Update our player's name and id
	our_player.set_name(str(client_id))
	our_player.set_id(client_id)
	
	# Remove all but our player from the players dictionary 
	for id in players:
		if id != old_client_id:
			players[id].queue_free()
	
	# Clear the players dictionary
	players = {}
	
	# Re-add our player to the players dictionary
	players[client_id] = our_player

# executes the client function specified by the server
# @param server_cmd - client function to call 
# @param args - arguments to pass into the command
remote func parse_server_rpc(server_cmd, args):
	#print("Command [" + server_cmd + "] called from server")
	callv(server_cmd, args)

# Called on ongoing or attempted connection failure
func _on_disconnect():
	offline = true
	print("server disconnected")

# Called when a connection attempt succeeds
func _on_connection_succeeded():
	offline = false

func say_zx():
	print("I said zx ok?? My name a ", client_id)

# called upon connecting to server, asks for our player's type information in order to construct a replica on server	
func send_blueprint():
	send_client_rpc("add_player", [my_type, my_team])
	print("sending blueprint for ", client_id)

##
## these functions handle sending most player commands to server
##

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


# adds a character to the local (client) scenetree
# int: id the player's network id
# string: type the player's class
# bool: mine whether or not this is our player
func add_a_player(id, type, team: int, initialization_values):
	var player_to_add
	
	match type:
		"base":
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

##
## Functions for syncing attributes (such as health, position, etc), objects, and actions
##

# Smoothly interpolates a node's position to where it probably will be in the next 1/60th of a second
func interpolate_node_position(node_name: String, projected_position: Vector2):
	var node_to_update = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_update):
		node_to_update.position += 0.1 * (projected_position - node_to_update.position)

var position_jump_limit = 50
func interpolate_player_position(player_id: int, projected_position: Vector2):
	var node_to_update = players[player_id]
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_update):
		# Calculate distance between client and server position
		if(node_to_update.position.distance_to(projected_position) > position_jump_limit):
			# jump to server position if we're too far
			node_to_update.position = projected_position
		else:
			# Interpolate if we're pretty close
			node_to_update.position += 0.3 * (projected_position - node_to_update.position)

# Updates an attribute of a player or object through interpolation
# The Node's path is relative to ChubbyServer
func update_node_attribute(node_name: String, attribute_name: String, updated_value) -> void:
	var node_to_update = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_update):
		pass

# Immediately sets an attribute of a node
# The Node's path is relative to ChubbyServer
func set_node_attribute(node_name: String, attribute_name: String, updated_value) -> void:
	var node_to_update = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_update):
		node_to_update.set(attribute_name, updated_value)

# used by server to call a method of a node
# The Node's path is relative to ChubbyServer
func call_node_method(node_name: String, method_name: String, args) -> void:
	var node_to_call = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_call):
		# call the method
		node_to_call.callv(method_name, args)
