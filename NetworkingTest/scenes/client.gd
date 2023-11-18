extends Node

var test_scene = preload("res://scenes/test_spawn.tscn")

# _physics_process is called a bunch of times in quick succession on startup
# so it will flood the server with like 8 messages, creating a megabuffer
const WARMUP_TIME = 0.5
const RECONCILIATION_SNAP_IF_ABOVE = 1000 # 0.25
const RECONCILIATION_SNAP_IF_BELOW = -1 # 0.001
const RECONCILIATION_EXPONENTIAL_FALLOFF = 0.5
const RECONCILIATION_VELOCITY_CORRECTION_FACTOR = 4.0
const RECONCILIATION_POSITION_CORRECTION_FACTOR = 0.0
const NO_SERVER_STATE = {"tick": -1}

@onready var input_handler: ClientInputHandler = $ClientInputHandler
@onready var character_spawner = $CharacterSpawner
@onready var messenger: NetworkMessenger = $NetworkMessenger

var client_character: CharacterMovementRigidBody = null
var character_physics_state: Dictionary = {}
var physics_state_per_tick: Dictionary = {}
var tick = 0

var reconciliation_vector_ = Vector3.ZERO
var is_reconciliation_enabled_ = true
var last_received_server_state: Dictionary = NO_SERVER_STATE
var latest_handled_tick: int = 0
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
	add_statistic("simulation_error", false, 200)
	add_statistic("reconciliation_frames", false, 500.0)
	add_statistic("horizontal_speed", false, 0.5)
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
	statistics["phys_frame_msec"].add_sample(Time.get_ticks_usec())
	if character_physics_state:
		statistics["horizontal_speed"].add_sample(sqrt(pow(character_physics_state.velocity.x, 2) + pow(character_physics_state.velocity.z, 2)))
	if !warmed_up or client_character == null:
		return
	reconcile_server_state(last_received_server_state.duplicate(true), delta)
	var player_input: Dictionary = input_handler.record_input_for_tick(tick)
	messenger.send_message_to_server({"input": player_input, "tick": tick})
	var correction_velocity = reconciliation_vector_ * RECONCILIATION_VELOCITY_CORRECTION_FACTOR
	character_physics_state = client_character.move_and_update_view(player_input, delta, character_physics_state, correction_velocity)
	physics_state_per_tick[tick] = {"state": character_physics_state, "floor": client_character.export_floor_contact}
	tick += 1

func replay():
	"""
	initial state: { "state": { "position": (0.306883, 1.75802, -3.356087), "velocity": (0.145179, -0.777604, 0.406038) }, "floor": { "normal": (0, 0, 0), "position": (0, 0, 0) } }
	server  state: { "position": (0.306883, 1.75802, -3.356087), "velocity": (0.145179, -0.777604, 0.406038) }
	simul   state: { "position": (0.30073, 1.76668, -3.354802), "velocity": (-0.027647, 0.369628, 0.296155) }
	simul   input: { "yaw": 231.1, "pitch": -17.95, "is_jumping": false, "direction": (0, -1) }
	simul   state: { "position": (0.297064, 1.766219, -3.352104), "velocity": (-0.154021, -0.057633, 0.203324) }
	simul   input: { "yaw": 231.1, "pitch": -17.95, "is_jumping": false, "direction": (0, -1) }
	current state: { "position": (0.290896, 1.751528, -3.355365), "velocity": (-0.090223, 0.227615, 0.283725) }
	error        : 0.01626357249916
	"""
	physics_state_per_tick[9999] = {}
	var begin_state = { "position": Vector3(0.306883, 1.75802, -3.356087), "velocity": Vector3(0.145179, -0.777604, 0.406038) }
	var inputs = [
		{ "yaw": 231.1, "pitch": -17.95, "is_jumping": false, "direction": Vector2(0, -1) },
		{ "yaw": 231.1, "pitch": -17.95, "is_jumping": false, "direction": Vector2(0, -1) }
	]
	var expected_state = { "position": Vector3(0.297064, 1.766219, -3.352104), "velocity": Vector3(-0.154021, -0.057633, 0.203324) }
	var delta = 0.0166666666667
	(simulate({"tick": 9999, "state": begin_state}, inputs, expected_state, delta).position - expected_state.position).length()

func reconcile_server_state(latest_server_message: Dictionary, delta: float):
	if is_reconciliation_enabled_ and latest_server_message["tick"] > latest_handled_tick:
		var inputs_since_state_tick = input_handler.get_inputs_since_tick(latest_server_message.tick + 1)
		var predicted_state: Dictionary = physics_state_per_tick[tick - 1].state
		var simulated_state = simulate(latest_server_message, inputs_since_state_tick, predicted_state, delta)
		var position_error = simulated_state["position"] - predicted_state["position"]
		var velocity_error = simulated_state["velocity"] - predicted_state["velocity"]
		statistics["simulation_error"].add_sample(position_error.length())
		if position_error.length() > RECONCILIATION_SNAP_IF_ABOVE or position_error.length() < RECONCILIATION_SNAP_IF_BELOW:
			character_physics_state = simulated_state
			reconciliation_vector_ = Vector3.ZERO
		else:
			reconciliation_vector_ = position_error * 0.02 # (reconciliation_vector_ * RECONCILIATION_EXPONENTIAL_FALLOFF) + (position_error * (1 - RECONCILIATION_EXPONENTIAL_FALLOFF))
#			character_physics_state.velocity = character_physics_state.velocity + velocity_error * 0.2
#			var corrected_state = predicted_state.duplicate()
#			corrected_state["velocity"] = simulated_state["velocity"] + (reconciliation_vector_ * RECONCILIATION_VELOCITY_CORRECTION_FACTOR)
#			corrected_state["position"] = corrected_state["position"] + (reconciliation_vector_ * RECONCILIATION_POSITION_CORRECTION_FACTOR)
#			print("rec vec: ", reconciliation_vector_)
#			print("pred: ", predicted_state)
#			print("corr: ", corrected_state)
#			character_physics_state = corrected_state
		latest_handled_tick = latest_server_message["tick"]
		last_received_server_state = NO_SERVER_STATE

func simulate(latest_server_message: Dictionary, inputs_since_state_tick: Array, current_physics_state: Dictionary, delta: float):
#	print("blep")
	var states_to_print = []
	states_to_print.push_back(physics_state_per_tick[latest_server_message.tick])
	# server state with tick X is from after input X has been processed. So next input is X+1 
	statistics["reconciliation_frames"].add_sample(inputs_since_state_tick.size())
	var simulation_state = latest_server_message.state
	states_to_print.push_back(simulation_state)
	for simulation_input in inputs_since_state_tick:
		simulation_state = client_character.move(simulation_state, simulation_input, delta)
		states_to_print.push_back(simulation_input)
		states_to_print.push_back(simulation_state)
	states_to_print.push_back(current_physics_state)
	var error = (current_physics_state.position - simulation_state.position).length()
	if error > 10.0001:
		print("initial state: ", states_to_print.pop_front())
		print("server  state: ", states_to_print.pop_front())
		while states_to_print.size() > 1:
			print("simul   input: ", states_to_print.pop_front())
			print("simul   state: ", states_to_print.pop_front())
		print("current state: ", states_to_print.pop_front())
		print("error        : ", error)
	return simulation_state

func _on_character_spawned(character: Node):
	if character.name == str(multiplayer.get_unique_id()):
		client_character = character

func resize_window():
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2.01, screen_size.y)
	get_window().position = Vector2(0, 0)
#	get_window().size = Vector2(screen_size.x, screen_size.y)
#	get_window().position = Vector2(0, 0)

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
