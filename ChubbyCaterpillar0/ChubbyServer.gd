extends Node

# You fools. this is actually the client code!

# TODO: 
# reduce hard_coding. Create port, ip, map, character selectors
# modify sendplayerrpc to only allow for the player to send its own phantom commands
#

# EXPLANATION:
# basically a central server and a client side middle server
# the client player send their movement instructions through rpc_unreliable_id
# and other instructions through reliable
# Instead of individual physics functions per player, make single_physics_frame functions and
# handle all of those through this file/node (chubbycaterpillar's server)
# For simplicity's sake

onready var Interpolator = get_node("Interpolator")
var uuid_generator = preload("res://server_resources/uuid_generator.tscn")
var ChubbyCharacter = preload("res://character/base_character/ChubbyCharacter.tscn")
var ChubbyCharacter0 = preload("res://character/game_characters/ChubbyCharacter0.tscn")
var ChubbyCharacter1 = preload("res://character/game_characters/ChubbyCharacter1.tscn")
var map = preload("res://maps/Map0.tscn")
var map2 = preload("res://maps/Map2.tscn")
var TimeQueue = preload("res://character/base_character/TimeQueue.tscn")

# hard coded. please change
const DEFAULT_PORT = 3342
var server_ip = "127.0.0.1"

# Node2d: client_uuid_generator a utility node which makes uuids...helps catalogue objects/timedeffects
var client_net = null # the ENet containing the client
var client_id := 0
var players = {} # tracks all connected players
var my_type := "pubert"
var my_team : int
var current_map
var client_uuid_generator = uuid_generator.instance()
var offline = false
var minmap_size = Vector2(1600, 1000)

# keeps track of client physics processing speed, used for interpolating server/client position
var client_delta = 1.0 / (ProjectSettings.get_setting("physics/common/physics_fps"))

##
## Signals
##
signal minimap_texture_updated(texture, origin)
signal player_spawned()

func _ready():
	$SelectionInput.connect("text_entered", self, "process_selection_input")

"""
func _process(delta):
	#if self.has_node(str(client_id)):
	#	$Camera2D.position += 0.08 * (get_node(str(client_id)).position - $Camera2D.position)
	
	if Input.is_action_pressed("ui_left"):
		$Camera2D.position += Vector2(-10,0)
	if Input.is_action_pressed("ui_right"):
		$Camera2D.position += Vector2(10,0)
	if Input.is_action_pressed("ui_up"):
		$Camera2D.position += Vector2(0,-10)
	if Input.is_action_pressed("ui_down"):
		$Camera2D.position += Vector2(0,10)
"""

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

func _unhandled_key_input(event):
	# Debug stuff
	if event is InputEventKey && event.pressed:
		if event.scancode == KEY_T:
			if not offline:
				print(str(client_net.get_connection_status()))
			elif client_net != null && client_net.get_connection_status() != 1: # client_net exists and isn't attempting connection
				reconnect()

func start_game_multiplayer():
	client_net = NetworkedMultiplayerENet.new()
	start_client()
	# Connect network signals
	client_net.connect("server_disconnected", self, "_on_disconnect")
	client_net.connect("connection_failed", self, "_on_disconnect")
	client_net.connect("connection_succeeded", self, "_on_connection_succeeded")
	
	# Adds our player
	add_a_player(client_id, my_type, my_team)
	
	# Add map and do initial processing for minimap
	var current_map = map2.instance()
	add_child(current_map)
	tilemap_to_tex(current_map.get_node("TileMap"))

func start_game_offline():
	$SelectionInput.queue_free()
	add_a_player(client_id, my_type, my_team)
	current_map = map2.instance()
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
func add_a_player(id, type, team: int):
	var player_to_add
	
	match type:
		"base":
			player_to_add = ChubbyCharacter.instance()
		"pubert":
			player_to_add = ChubbyCharacter0.instance()
		"squeegee":
			player_to_add = ChubbyCharacter1.instance()
		_:
			player_to_add = ChubbyCharacter.instance()
	
	# sets player node's name and id and team
	player_to_add.set_id(id)
	player_to_add.set_name(str(id))
	player_to_add.team = team
	player_to_add.set_team(team)
	
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
	get_node("/root/ChubbyServer").add_child(player_to_add)
	
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

var position_jump_limit = 60
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
			node_to_update.position += 0.1 * (projected_position - node_to_update.position)

# Updates an attribute of a player or object through interpolation
# The Node's path is relative to ChubbyServer
func update_node_attribute(node_name: String, attribute_name: String, updated_value) -> void:
	var node_to_update = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_update):
		Interpolator.interpolate_property(node_to_update, attribute_name, node_to_update.get(attribute_name), updated_value, client_delta, Tween.TRANS_ELASTIC, Tween.EASE_IN_OUT)
		Interpolator.start()

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


##
## Deprecated functions
##

# used by server to call a method of a player
func call_player_method(player_id: int, method_name: String, args) -> void:
	# if we have a player node with the specified name, and that player isn't us
	if self.has_node(str(player_id)):
		# call the method of the player with its args
		players[player_id].callv(method_name, args)

func add_other_player(id, type):
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

# unused
# called by server to remove a player object, such as a projectile. client can't remove them by itself
func remove_player_object(player_id: int, object_uuid: String) -> void:
	if self.has_node(str(player_id)):
		players[player_id].callv("remove_object", [object_uuid])

# updates position of a player based on recent server info
func parse_updated_player_position_from_server(id, latest_server_position):
	# Interpolates between client position and server position using client_delta, aka physics processing rate, to determine a smooth speed
	Interpolator.interpolate_property(get_node("/root/ChubbyServer/" + str(id)), "position", players[id].get_global_position(), latest_server_position, client_delta, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	Interpolator.start()
#	get_node("/root/ChubbyServer/" + str(id)).set("position", latest_server_position) 


# Linearly interpolates a NON-ESSENTIAL player attribute based on latest server information
func update_player_attribute(player_id: int, attribute_name: String, latest_server_info) -> void:
	# Interpolates between client position and server position using client_delta, aka physics processing rate, to determine a smooth speed
	Interpolator.interpolate_property(get_node("/root/ChubbyServer/" + str(player_id)), attribute_name, players[player_id].get(attribute_name), latest_server_info, client_delta * 5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	Interpolator.start()
	#get_node("/root/ChubbyServer/" + str(player_id)).set(attribute_name, latest_server_info)


# Immediately sets an ESSENTIAL player attribute based on latest server information
func set_player_attribute(player_id: int, attribute_name: String, latest_server_info) -> void:
	get_node("/root/ChubbyServer/" + str(player_id)).set(attribute_name, latest_server_info)

# 
func update_timed_effect(player_id: int, timed_effect_id: int, server_current_iterations: int) -> void:
	get_node("/root/ChubbyServer/" + str(player_id)).timed_effects[timed_effect_id].update(server_current_iterations)

# general add player
# function not used for now...may come in handy when switching player control
remote func add_random_player(id, type):
	if (!players.has(id)):
		var chubby_character

		match type:
			"base":
				chubby_character = ChubbyCharacter.instance()
			_:
				chubby_character = ChubbyCharacter0.instance()

		chubby_character.set_id(id)
		chubby_character.set_name(str(id))
		
		if (id == client_id):
			chubby_character.set_network_master(id)
			
			# camera follow
			var camera = get_node("Camera2D")
			remove_child(camera)
			chubby_character.add_child(camera)
		
		get_node("/root/ChubbyServer").add_child(chubby_character)
		players[id] = chubby_character
	
