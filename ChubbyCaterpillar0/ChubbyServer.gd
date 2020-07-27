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
var ChubbyCharacter1 = preload("res://character/experimental_character/ChubbyCharacter_experimental_0.tscn")
var map = preload("res://maps/Map0.tscn")
var map2 = preload("res://maps/Map2.tscn")
var TimeQueue = preload("res://character/base_character/TimeQueue.tscn")

# hard coded. please change
const DEFAULT_PORT = 3342
var server_ip = "127.0.0.1"

# Node2d: client_uuid_generator a utility node which makes uuids...helps catalogue objects/timedeffects
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

func _process(delta):
	if self.has_node(str(client_id)):
		$MinMapBoi.position = get_node(str(client_id)).position

func process_selection_input(selection: String):
	var split_selection = selection.split(",", false)
	offline = bool(int(split_selection[0]))
	my_team = int(split_selection[1])
	server_ip = split_selection[2]
	if offline:
		start_game_offline()
	else:
		start_game_multiplayer()
	$SelectionInput.queue_free()


func start_game_multiplayer():
	start_client()
	client_id = get_tree().get_network_unique_id()
	print(client_id)
	add_a_player(client_id, my_type, my_team)
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
	var client = NetworkedMultiplayerENet.new()
	client.create_client(server_ip, DEFAULT_PORT)
	get_tree().set_network_peer(client)
	print("client created")

# executes the client function specified by the server
# @param server_cmd - client function to call 
# @param args - arguments to pass into the command
remote func parse_server_rpc(server_cmd, args):
	#print("Command [" + server_cmd + "] called from server")

	callv(server_cmd, args)

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


# Updates an attribute of a player or object
# The Node's path is relative to ChubbyServer
func update_node_attribute(node_name: String, attribute_name: String, updated_value) -> void:
	var node_to_update = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_update):
		Interpolator.interpolate_property(node_to_update, attribute_name, node_to_update.get(attribute_name), updated_value, 5 * client_delta, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		Interpolator.start()

# used by server to call a method of a node
# The Node's path is relative to ChubbyServer
func call_node_method(node_name: String, method_name: String, args) -> void:
	var node_to_call = get_node("/root/ChubbyServer/" + node_name)
	# checks if node exists before attempting to change its properties
	if is_instance_valid(node_to_call):
		# call the method
		node_to_call.callv(method_name, args)

# used by server to call a method of a player
func call_player_method(player_id: int, method_name: String, args) -> void:
	# if we have a player node with the specified name, and that player isn't us
	if self.has_node(str(player_id)):
		# call the method of the player with its args
		players[player_id].callv(method_name, args)


##
## Deprecated functions
##

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
	
