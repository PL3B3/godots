extends Node

@onready var messenger: NetworkMessenger = $NetworkMessenger
@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var character_spawner: MultiplayerSpawner = $CharacterSpawner

var test_scene = preload("res://scenes/test_spawn.tscn")

var client_character: CharacterMovementRigidBody = null
var character_physics_state: Dictionary = {}
var client_id: int = -1
var client_inputs = []
var statistics = {}

func _ready():
	resize_window()
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	messenger.received_client_message.connect(_handle_client_message)
#	add_statistic("input_receive_to_process_usec", false, 2)
	add_statistic("cl_ts_to_sv_ts", false, 2000)
	add_statistic("sv_buffer_size", false, 2000)
	map_spawner.spawn(null)
	# creates a frametime offset 
#	Engine.max_fps = 53
#	get_tree().create_timer(0.8).timeout.connect(func(): Engine.max_fps = 120)

var last_recv_ts = 0
func _handle_client_message(id, message):
	var enriched_message = message.duplicate()
	enriched_message["received_usec"] = Time.get_ticks_usec()
	client_inputs.push_back(enriched_message)
#	print("recv usec: ", Time.get_ticks_usec())
#	print("diff usec: ", Time.get_ticks_usec() - last_phys_ts)
	last_recv_ts = Time.get_ticks_usec()

var last_phys_ts = 0
var ewma_factor = 0.99
var initial_tick_diff = 0
func _physics_process(delta):
#	if Input.is_action_just_pressed("ui_down"):
#		print("waiting")
#		await get_tree().create_timer(5.0).timeout
#	if !client_inputs.is_empty():
#		print("usec diff: ", (Time.get_ticks_usec() - client_inputs[0]["client_timestamp"]) - initial_tick_diff, " input buff: ", client_inputs.size())
#		print(fmod(Time.get_ticks_usec() - client_inputs[-1]["client_timestamp"], 16666))
#		statistics["cl_ts_to_sv_ts"].add_sample(fmod(Time.get_ticks_usec() - client_inputs[-1]["client_timestamp"], 16666))
#		initial_tick_diff = (initial_tick_diff * ewma_factor) + (1 - ewma_factor) * (Time.get_ticks_usec() - client_inputs[0]["client_timestamp"])
#		print(initial_tick_diff)
#	print("sv time: ", Time.get_ticks_usec() - last_phys_ts)
#	print("input size: ", client_inputs.size())
	statistics["sv_buffer_size"].add_sample(client_inputs.size())
	if client_character != null and !client_inputs.is_empty():
		while client_inputs.size() > 10:
			print(Time.get_time_string_from_system(), " Too many queued inputs, popping")
			client_inputs.pop_front()
		var input = client_inputs.pop_front()
#		print(Time.get_unix_time_from_system() - input["client_timestamp"])
#		print("usec diff: ", (Time.get_ticks_usec() - input["client_timestamp"]) - initial_tick_diff, " input buff: ", client_inputs.size())
#		if character_physics_state:
#			character_physics_state.position = character_physics_state.position + add_random_movement(input["tick"])
		character_physics_state = client_character.move_and_update_view(input["input"], delta, character_physics_state) # client_character.handle_input_frame(input)
		messenger.send_message_to_client(client_id, {"state": character_physics_state, "tick": input["tick"]})
	last_phys_ts = Time.get_ticks_usec()

func add_random_movement(tick):
	var rng = RandomNumberGenerator.new()
	if tick % 60 == 0:
		var horizontal_component = 0.1 * Vector3.FORWARD.rotated(Vector3.UP, rng.randf_range(0, 2 * PI))
		var vertical_component = Vector3(0, rng.randf_range(0, 1), 0)
		return horizontal_component
	else:
		return Vector3.ZERO

func resize_window():
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2, screen_size.y)
	get_window().position = Vector2(screen_size.x / 2, 0)

func _on_client_connected(id: int):
	client_character = character_spawner.spawn({"id": id, "position": Vector3(5.251241, 3.197067, 4.925832)})
	client_id = id
	print("Client with id ", id, " connected")
	
func _on_client_disconnected(id: int):
	print("Client with id ", id, " disconnected")
	
	
func add_statistic(stat_name, use_diff, interval):
	var statistic = Statistics.new(stat_name, use_diff, interval)
	statistics[stat_name] = statistic
	add_child(statistic)
