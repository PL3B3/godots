extends Node

# -----------------------------------------------------------Preloaded Resources
var base_character = preload("res://common/characters/BaseCharacter.tscn")
var base_fauna = preload("res://common/fauna/BaseFauna.tscn")
var podunk = preload("res://common/envs/impl_envs/Podunk.tscn")

# -----------------------------------------------------------Constants and Enums
const DEFAULT_PORT = 3342
enum Species {BASE, PUBERT, SQUEEGEE, PUMBITA, JINGLING, SHIMMER, CAPIND, PUMPQUEEN}
enum Sign {TERROR, ERRANT, VULN}
enum Map {PODUNK}
const ability_conversions = {
	"mouse_ability_0" : 0,
	"mouse_ability_1" : 1, 
	"key_ability_0" : 2, 
	"key_ability_1" : 3, 
	"key_ability_2" : 4}

# -----------------------------------------------------------Functionality Nodes
var uuid_gen = preload("res://common/utils/UUIDGenerator.gd")
var interpolator = Tween.new()
var periodic_timer = Timer.new()
var periodic_timer_period = 1

# -----------------------------------------------------------------------Signals


var server_delta
var network_id := 0
var players = {}

var map_type = Map.PODUNK
var map_node
var team_respawn_positions = [
	Vector3(0, 50, 0),
	Vector3(0, 50, 0),
	Vector3(0, 50, 0),
	Vector3(0, 50, 0),
	Vector3(0, 50, 0),
	Vector3(0, 50, 0)]

func _ready():
	# functionality node initialization
	add_child(periodic_timer)
	periodic_timer.start(periodic_timer_period)
	add_child(interpolator)
	
	# connections
	periodic_timer.connect("timeout", self, "_periodic", [periodic_timer_period])

func _periodic(timer_period):
	pass

# --------------------------------------------------------------------Game Setup

func add_map():
	var map_to_add
	match map_type:
		Map.PODUNK:
			map_to_add = podunk.instance()
		_:
			map_to_add = podunk.instance()
	map_node = map_to_add
	
	add_child(map_node)
	
	team_respawn_positions = map_node.team_respawn_positions

func spawn_targets(num_targets):
	for i in range(num_targets):
		var target = base_fauna.instance()
		target.transform.origin = (
			Vector3(0, 4, 0) + 
			5 * (
				Vector3(cos(2 * PI * float(i) / num_targets), 0, sin(2 * PI * float(i) / num_targets))
			))
		add_child(target)

# --------------------------------------------------------------Handling Players

func initialize_and_add_player(id, species, team, origin, initialization_values) -> KinematicBody:
	var player_to_add = null
	match species:
		Species.BASE:
			player_to_add = base_character.instance()
		_:
			player_to_add = base_character.instance()
	
	player_to_add.set_name(str(id))
	player_to_add.set_basic_values(species, team, origin)
	player_to_add.set_initialization_values(initialization_values)
	
	add_child(player_to_add)
	players[id] = player_to_add
	
	periodic_timer.connect("timeout", player_to_add, "_periodic", [periodic_timer_period])
	
	return player_to_add

func remove_player(player_id):
	# Checks if not already removed
	print("Removing player ", player_id)
	if (players.has(player_id)):
		players.erase(player_id)
		var disconnected_player_node = get_node("/root/Server/" + str(player_id))
		disconnected_player_node.queue_free()
	else:
		print("Trying to remove nonexistent player")

# -----------------------------------------------------------------------Utility

var ping_avg = 0
var ping_avg_unreliable = 0
var new_ping_weight = 0.2
var ping_dict = {}

# flag indicates if the ping is beginning (0), response (1), or conclude (2)
remotesync func ping(args):
	var start_time = OS.get_ticks_usec()
	var id = args[0]
	var uuid = args[1]
	var flag = args[2]
	#print("ping called from %s with id %s and flag %d" % [id, uuid, flag])
	if flag == 0:
		var uuid_to_send = uuid_gen.v4()
		if ping_dict.has(id):
			ping_dict[id][uuid_to_send] = OS.get_ticks_usec()
		else:
			ping_dict[id] = {}
			ping_dict[id][uuid_to_send] = OS.get_ticks_usec()
		rpc_id(id, "ping", [network_id, uuid_to_send, flag + 1])
	elif flag == 1:
		rpc_id(get_tree().get_rpc_sender_id(), "ping", [network_id, uuid, flag + 1])
	elif flag == 2:
		var ping_time = (OS.get_ticks_usec() - ping_dict[id][uuid])
		#print(ping_time)
		if ping_avg == 0:
			ping_avg = ping_time
		else:
			ping_avg = ((
					ping_avg + 
					new_ping_weight * ping_time) / 
					(1 + new_ping_weight))
		ping_dict[id].erase(uuid)

remotesync func ping_unreliable(args):
	var id = args[0]
	var uuid = args[1]
	var flag = args[2]
	if flag == 0:
		var uuid_to_send = uuid_gen.v4()
		if ping_dict.has(id):
			ping_dict[id][uuid_to_send] = OS.get_ticks_usec()
		else:
			ping_dict[id] = {}
			ping_dict[id][uuid_to_send] = OS.get_ticks_usec()
		rpc_id(id, "ping_unreliable", [network_id, uuid_to_send, flag + 1])
	elif flag == 1:
		rpc_unreliable_id(get_tree().get_rpc_sender_id(), "ping_unreliable", [network_id, uuid, flag + 1])
	elif flag == 2:
		var ping_time = (OS.get_ticks_usec() - ping_dict[id][uuid])
		#print(ping_time)
		if ping_avg_unreliable == 0:
			ping_avg_unreliable = ping_time
		else:
			ping_avg_unreliable = ((
					ping_avg_unreliable + 
					new_ping_weight * ping_time) / 
					(1 + new_ping_weight))
		ping_dict[id].erase(uuid)
