extends Node

var test_scene = preload("res://scenes/test_spawn.tscn")

# _physics_process is called a bunch of times in quick succession on startup
# so it will flood the server with like 8 messages, creating a megabuffer
const WARMUP_TIME = 0.5
const RECONCILIATION_SNAP_THRESHOLD = 0.5
const RECONCILIATION_EXPONENTIAL_FALLOFF = 0.5
const RECONCILIATION_VELOCITY_CORRECTION_FACTOR = 4.0
const RECONCILIATION_POSITION_CORRECTION_FACTOR = 0.0
const NO_SERVER_STATE = {"tick": -1}

@onready var input_handler = $ClientInputHandler
@onready var character_spawner = $CharacterSpawner
@onready var messenger: NetworkMessenger = $NetworkMessenger

var client_character: CharacterMovementBody = null
var tick = 0

var reconciliation_vector_ = Vector3.ZERO
var is_reconciliation_enabled_ = true
var last_received_server_state: Dictionary = NO_SERVER_STATE
var latest_handled_tick: int = 0
var input_for_tick_ = {} 
var warmed_up = false
var statistics = {}

func _ready():
	resize_window()
#	multiplayer.peer_connected.connect(_on_peer_connected)
#	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_failed_to_connect_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	character_spawner.spawned.connect(_on_character_spawned)
	messenger.received_server_message.connect(_handle_server_message)
	get_tree().create_timer(WARMUP_TIME).timeout.connect(func(): warmed_up = true)
	add_statistic("phys_frame_msec", true, 1000)
	add_statistic("simulation_error", false, 0.5)
	# done last so  we don't connect before spawn_function gets set
	start_client()

func add_statistic(stat_name, use_diff, interval):
	var statistic = Statistics.new(stat_name, use_diff, interval)
	statistics[stat_name] = statistic
	add_child(statistic)

func _handle_server_message(message):
	if message["tick"] > latest_handled_tick:
		last_received_server_state = message

func start_client():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(Network.DEFAULT_SERVER_IP, Network.PORT)
	if error: 
		return error
	multiplayer.multiplayer_peer = peer



func _physics_process(delta):
#	print("cl time: ", Time.get_unix_time_from_system())
	statistics["phys_frame_msec"].add_sample(Time.get_ticks_usec())
	if !warmed_up or client_character == null:
		return
	# check if unhandled tick state from server
	var state = last_received_server_state.duplicate(true)
	if is_reconciliation_enabled_ and state["tick"] > latest_handled_tick:
		var simulation_result = simulate(state, delta)
		var predicted_state = simulation_result["predicted_state"]
		var simulated_state = simulation_result["simulated_state"]
		var prediction_error = simulated_state["position"] - predicted_state["position"]
		statistics["simulation_error"].add_sample(prediction_error.length())
		if prediction_error.length() > RECONCILIATION_SNAP_THRESHOLD:
			client_character.update_state(simulated_state)
			reconciliation_vector_ = Vector3.ZERO
		else:
			reconciliation_vector_ = (reconciliation_vector_ * RECONCILIATION_EXPONENTIAL_FALLOFF) + prediction_error
			var corrected_state = predicted_state.duplicate()
			corrected_state["velocity"] = simulated_state["velocity"] + (reconciliation_vector_ * RECONCILIATION_VELOCITY_CORRECTION_FACTOR)
			corrected_state["position"] = corrected_state["position"] + (reconciliation_vector_ * RECONCILIATION_POSITION_CORRECTION_FACTOR)
#			client_character.update_state(corrected_state)
		latest_handled_tick = state["tick"]
		last_received_server_state = NO_SERVER_STATE
	# get input for frame
	var input = input_handler.record_input_for_tick(tick, delta)
	input_for_tick_[tick] = input
	input["client_timestamp"] = Time.get_ticks_usec()
	messenger.send_message_to_server(input)
	client_character.handle_input_frame(input)
	tick += 1

func simulate(server_state, delta):
	var character_state_before_simulation = client_character.get_current_state()
	var inputs_since_state_tick = []
	# server state with tick X is from after input X has been processed. So next input is X+1 
	var simulation_tick = server_state["tick"] + 1
	while input_for_tick_.has(simulation_tick):
		inputs_since_state_tick.push_back(input_for_tick_[simulation_tick])
		simulation_tick += 1
#	statistics["simulation_error"].add_sample(inputs_since_state_tick.size())
	
	var character_simulation_state = server_state.duplicate()
	for simulation_input in inputs_since_state_tick:
		client_character.update_state(character_simulation_state)
		character_simulation_state = client_character.move(simulation_input)
		
	return {
		"simulated_state": character_simulation_state,
		"predicted_state": character_state_before_simulation
	}

func _on_character_spawned(character: Node):
	if character.name == str(multiplayer.get_unique_id()):
		client_character = character

func resize_window():
	var screen_size: Vector2 = DisplayServer.screen_get_size()
#	get_window().size = Vector2(screen_size.x / 2.01, screen_size.y)
#	get_window().position = Vector2(0, 0)
	get_window().size = Vector2(screen_size.x, screen_size.y)
	get_window().position = Vector2(0, 0)

func _on_peer_connected(id: int):
	print("Peer with id ", id, " connected")

func _on_peer_disconnected(id: int):
	print("Peer with id ", id, " disconnected")

func _on_connected_to_server():
	pass
	
func _on_failed_to_connect_to_server():
	pass
	
func _on_server_disconnected():
	pass
