extends Node

const EMPTY_PHYSICS_STATE = {}
const SPAWN_POINT_RANDOM_VARIATION = 5
const SPAWN_POINT = Vector3(0, 2.5, 0)

@onready var messenger: NetworkMessenger = $NetworkMessenger
@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var character_spawner: MultiplayerSpawner = $CharacterSpawner

var test_scene = preload("res://scenes/test_spawn.tscn")

var rng = RandomNumberGenerator.new()
var client_character: CharacterMovementKinematicBody = null
var character_physics_state: Dictionary = {}
var client_id: int = -1
var client_inputs = []

var character_simulation_per_client: Dictionary = {}

func _ready():
	resize_window()
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	messenger.received_client_message.connect(_handle_client_message)
	LogsAndMetrics.add_server_stat("sv_buffer_size")
	map_spawner.spawn(null)

func _handle_client_message(id, message):
	character_simulation_per_client[id].add_client_message(message)

var last_phys_ts = 0
var initial_tick_diff = 0
func _physics_process(delta):
	for client_id in character_simulation_per_client:
		var simulation_for_client: CharacterSimulation = character_simulation_per_client[client_id]
		simulation_for_client.advance_state_and_notify_clients(character_simulation_per_client.keys())

func resize_window(index=0):
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2, screen_size.y / 2)
	get_window().position = Vector2(screen_size.x / 2, index * (screen_size.y / 2))

func _on_client_connected(id: int):
	var spawn_point = SPAWN_POINT + SPAWN_POINT_RANDOM_VARIATION * Vector3(rng.randf_range(-1,1), 0, rng.randf_range(-1,1))
	var client_connection_index = character_simulation_per_client.size()
	var client_character = character_spawner.spawn({"id": id, "position": spawn_point})
	character_simulation_per_client[id] = CharacterSimulation.new(id, client_character, messenger)
	messenger.send_message_to_client(id, { "resize": client_connection_index , "type": Network.MessageType.RESIZE })
	resize_window(client_connection_index)
	print("Client with id ", id, " connected")
	
func _on_client_disconnected(id: int):
	print("Client with id ", id, " disconnected")

class CharacterSimulation:
	const EMPTY_INPUT_FOR_BUFFERING = { "INPUT": "EMPTY" }
	const ARTIFICIAL_INPUT_BUFFER_AMOUNT = 6
	
	var client_id_: int
	var character_
	var messages_: Array = []
	var network_messenger_: NetworkMessenger
	var character_physics_state_: Dictionary
	var rng_ = RandomNumberGenerator.new()
	
	func _init(client_id, character, network_messenger):
		character_physics_state_ = character.starting_physics_state()
		character_ = character
		client_id_ = client_id
		network_messenger_ = network_messenger
	
	func add_client_message(message):
		if messages_.is_empty():
			for i in ARTIFICIAL_INPUT_BUFFER_AMOUNT:
				messages_.push_back(EMPTY_INPUT_FOR_BUFFERING)
		messages_.push_back(message)
	
	func advance_state_and_notify_clients(client_ids: Array):
		#print("buff size: %d" % messages_.size())
		if messages_.is_empty():
			#print(Time.get_unix_time_from_system(), " ---- NO CLIENT INPUTS")
			return
		
		var message_to_process = messages_.pop_front()
		if message_to_process != EMPTY_INPUT_FOR_BUFFERING:
			#character_physics_state_.position += compute_random_movement(message_to_process["tick"])
			var input_to_simulate = message_to_process["input"]
			character_physics_state_ = character_.compute_next_physics_state(character_physics_state_, input_to_simulate)
			var player_state_message = { 
				"type": Network.MessageType.PLAYER_STATE,
				"state": character_physics_state_, 
				"tick": message_to_process["tick"] 
			}
			network_messenger_.send_message_to_client(client_id_, player_state_message)
			for other_client_id in client_ids.filter(func(peer_id): return peer_id != client_id_):
				var puppet_state_message = { 
					"type": Network.MessageType.PUPPET_STATE,
					"position": character_physics_state_.position, 
					"tick": message_to_process["tick"],
					"pitch": input_to_simulate.pitch,
					"yaw": input_to_simulate.yaw,
					"puppet_id": client_id_
				}
				network_messenger_.send_message_to_client(other_client_id, puppet_state_message)
	
	func compute_random_movement(tick):
		if tick % 60 == 0:
			var horizontal_component = 2 * Vector3.FORWARD.rotated(Vector3.UP, rng_.randf_range(0, 2 * PI))
			var vertical_component = Vector3(0, rng_.randf_range(0, 1), 0)
			return horizontal_component
		else:
			return Vector3.ZERO

func old_simulate():
	last_phys_ts = Time.get_ticks_usec()
	if client_character != null:
		$Label2.set_text(str(client_inputs.size()))
		LogsAndMetrics.add_sample("sv_buffer_size", client_inputs.size())
		if client_inputs.is_empty():
			pass
			#print(Time.get_unix_time_from_system(), " ---- NO CLIENT INPUTS")
		else:
			#while client_inputs.size() > 1500:
				#print(Time.get_time_string_from_system(), " Too many queued inputs, popping")
				#client_inputs.pop_front()
			var input = client_inputs.pop_front()
			#if input != EMPTY_INPUT_FOR_BUFFERING:
				##print(Time.get_unix_time_from_system() - input["client_timestamp"])
				##print("usec diff: ", (Time.get_ticks_usec() - input["client_timestamp"]) - initial_tick_diff, " input buff: ", client_inputs.size())
				##if character_physics_state:
					##character_physics_state.position = character_physics_state.position + add_random_movement(input["tick"])
				#character_physics_state = client_character.compute_next_physics_state(character_physics_state, input["input"]) # client_character.handle_input_frame(input)
				#messenger.send_message_to_client(client_id, {"state": character_physics_state, "tick": input["tick"]})
