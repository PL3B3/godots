extends Node

var test_scene = preload("res://scenes/test_spawn.tscn")

# _physics_process is called a bunch of times in quick succession on startup
# so it will flood the server with like 8 messages, creating a megabuffer
# set to 0 to disable, if you want the buffer
const WARMUP_TIME = 0.0
const RECONCILIATION_SNAP_IF_ABOVE = 10.25
const RECONCILIATION_SNAP_IF_BELOW = 0.001
const RECONCILIATION_EXPONENTIAL_FALLOFF = 0.5
const RECONCILIATION_VELOCITY_CORRECTION_FACTOR = 4.0
const RECONCILIATION_POSITION_CORRECTION_FACTOR = 0.0
const NO_SERVER_STATE = {"tick": -1}

@onready var input_handler: ClientInputHandler = $ClientInputHandler
@onready var character_spawner = $CharacterSpawner
@onready var messenger: NetworkMessenger = $NetworkMessenger

var puppets: Dictionary = {}
var client_character: Character = null
var character_physics_state: Dictionary = {}
var physics_state_per_tick: Dictionary = {}
var tick = 0

var is_reconciliation_enabled_ = true
var is_replay_enabled_ = false
var last_received_server_state: Dictionary = NO_SERVER_STATE
var latest_handled_tick: int = 0
var warmed_up = false

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
	LogsAndMetrics.add_client_stat("sim_error", 2, false)
	# done after wiring signals so we don't connect to server before spawn_function gets set
	start_client()

func _process(delta):
	if Input.is_action_just_pressed("toggle_window_mode"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _physics_process(delta):
	if !warmed_up or client_character == null:
		return
	if is_replay_enabled_:
		replay()
		return
	client_character.reconcile_server_state(last_received_server_state.duplicate(true), delta)
	#character_physics_state = reconcile_server_state(last_received_server_state.duplicate(true), delta)
	var player_input: Dictionary = input_handler.record_input_for_tick(tick)
	messenger.send_message_to_server({"input": player_input, "tick": tick})
	character_physics_state = client_character.compute_next_physics_state(character_physics_state, player_input)
	physics_state_per_tick[tick] = {"state": character_physics_state, "floor": null} # client_character.export_floor_contact
	tick += 1

func reconcile_server_state(latest_server_message: Dictionary, delta: float):
	if is_reconciliation_enabled_ and latest_server_message["tick"] > latest_handled_tick:
		var inputs_since_state_tick = input_handler.get_inputs_since_tick(latest_server_message.tick + 1)
		var predicted_state: Dictionary = physics_state_per_tick[tick - 1].state
		var simulated_state = simulate(latest_server_message, inputs_since_state_tick, predicted_state, delta)
		var position_error = simulated_state["position"] - predicted_state["position"]
		var velocity_error = simulated_state["velocity"] - predicted_state["velocity"]
		LogsAndMetrics.add_sample("sim_error", position_error.length())
		latest_handled_tick = latest_server_message["tick"]
		last_received_server_state = NO_SERVER_STATE
		if position_error.length() > RECONCILIATION_SNAP_IF_ABOVE or position_error.length() < RECONCILIATION_SNAP_IF_BELOW:
			return simulated_state
		else:
			var corrected_state = predicted_state.duplicate()
			corrected_state.position = corrected_state.position.lerp(simulated_state.position, 0.15)
			corrected_state.velocity = simulated_state.velocity
			return corrected_state
			# (reconciliation_vector_ * RECONCILIATION_EXPONENTIAL_FALLOFF) + (position_error * (1 - RECONCILIATION_EXPONENTIAL_FALLOFF))
			#character_physics_state.velocity = character_physics_state.velocity + velocity_error * 0.2
			#var corrected_state = predicted_state.duplicate()
			#corrected_state["velocity"] = simulated_state["velocity"] + (reconciliation_vector_ * RECONCILIATION_VELOCITY_CORRECTION_FACTOR)
			#corrected_state["position"] = corrected_state["position"] + (reconciliation_vector_ * RECONCILIATION_POSITION_CORRECTION_FACTOR)
			#print("rec vec: ", reconciliation_vector_)
			#print("pred: ", predicted_state)
			#print("corr: ", corrected_state)
			#character_physics_state = corrected_state
		#if position_error.length() > 0.25:
			#print("predstate: ", predicted_state)
			#print("sim state: ", simulated_state)
			#print("sv    msg: ", last_received_server_state)
			#print("sim ticks: ", inputs_since_state_tick.size())
	else:
		return character_physics_state

func simulate(latest_server_message: Dictionary, inputs_since_state_tick: Array, current_physics_state: Dictionary, delta: float):
#	print("blep")
	var states_to_print = []
	states_to_print.push_back(physics_state_per_tick[latest_server_message.tick])
	# server state with tick X is from after input X has been processed. So next input is X+1 
	var simulation_state = latest_server_message.state
	states_to_print.push_back(latest_server_message)
	for simulation_input in inputs_since_state_tick:
		#simulation_state = client_character.move(simulation_state, simulation_input, delta)
		simulation_state = client_character.compute_next_physics_state(simulation_state, simulation_input)
		states_to_print.push_back(simulation_input)
		states_to_print.push_back(simulation_state)
	states_to_print.push_back(current_physics_state)
	var error = (current_physics_state.position - simulation_state.position).length()
	#if error > 0.01:
		#print_replay_string(states_to_print)
		#print(Time.get_unix_time_from_system())
		#print("initial state: ", states_to_print.pop_front())
		#print("server  state: ", states_to_print.pop_front())
		#while states_to_print.size() > 1:
			#print("simul   input: ", states_to_print.pop_front())
			#print("simul   state: ", states_to_print.pop_front())
		#print("current state: ", states_to_print.pop_front())
		#print("error        : ", error)
		#print("current  tick: ", tick)
	return simulation_state

func replay():
	"""
	initial state: { "state": { "velocity": (-3.253312, 1.662395, 12.52345), "position": (12.34433, 2.528003, -20.23211), "is_moving_along_floor": true }, "floor": <null> }
	server  state: { "velocity": (-3.253312, 1.662395, 12.52345), "position": (12.34433, 2.528003, -20.23211), "is_moving_along_floor": true }
	simul   input: { "yaw": 69.7000000000016, "pitch": -9.84999999999985, "is_jumping": false, "is_slow_walking": false, "direction": (-0.707107, -0.707107) }
	simul   state: { "velocity": (-4.152638, 2.039824, 12.83182), "position": (12.27584, 2.53448, -20.01805), "is_moving_along_floor": true }
	simul   input: { "yaw": 67.8000000000016, "pitch": -9.79999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (-0.707107, -0.707107) }
	simul   state: { "velocity": (-7.301629, 30.30303, 12.30783), "position": (12.15415, 3.03953, -19.81292), "is_moving_along_floor": false }
	simul   input: { "yaw": 65.5500000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (-0.707107, -0.707107) }
	simul   state: { "velocity": (-9.986217, 30.30303, 11.71913), "position": (11.98771, 3.544581, -19.6176), "is_moving_along_floor": false }
	simul   input: { "yaw": 63.1000000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (-0.707107, -0.707107) }
	simul   state: { "velocity": (-11.04252, 28.77257, 11.68186), "position": (11.80367, 4.024124, -19.4229), "is_moving_along_floor": false }
	simul   input: { "yaw": 59.1000000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (0, -1) }
	simul   state: { "velocity": (-12.97788, 27.24212, 10.20793), "position": (11.58737, 4.478159, -19.25277), "is_moving_along_floor": false }
	simul   input: { "yaw": 56.2500000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (0, -1) }
	simul   state: { "velocity": (-14.64069, 25.71166, 8.673415), "position": (11.34336, 4.906687, -19.10821), "is_moving_along_floor": false }
	simul   input: { "yaw": 53.4000000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (0, -1) }
	simul   state: { "velocity": (-16.06124, 24.1812, 7.103917), "position": (11.07567, 5.309707, -18.98981), "is_moving_along_floor": false }
	simul   input: { "yaw": 50.6500000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (0.707107, -0.707107) }
	simul   state: { "velocity": (-16.26135, 22.65075, 5.081247), "position": (10.80465, 5.687219, -18.90512), "is_moving_along_floor": false }
	simul   input: { "yaw": 47.0500000000016, "pitch": -9.64999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (0.707107, -0.707107) }
	simul   state: { "velocity": (-16.33169, 21.12029, 3.116086), "position": (10.53246, 6.039224, -18.85319), "is_moving_along_floor": false }
	simul   input: { "yaw": 44.9000000000016, "pitch": -9.84999999999985, "is_jumping": true, "is_slow_walking": false, "direction": (0.707107, -0.707107) }
	simul   state: { "velocity": (-16.32842, 19.58983, 1.239783), "position": (10.26032, 6.365721, -18.83253), "is_moving_along_floor": false }
	simul   input: { "yaw": 42.9500000000016, "pitch": -10.0499999999998, "is_jumping": true, "is_slow_walking": false, "direction": (0.707107, -0.707107) }
	simul   state: { "velocity": (-16.26445, 18.05938, -0.547279), "position": (9.989242, 6.666711, -18.84165), "is_moving_along_floor": false }
	simul   input: { "yaw": 41.3500000000016, "pitch": -10.2999999999998, "is_jumping": true, "is_slow_walking": false, "direction": (1, 0) }
	simul   state: { "velocity": (-14.42036, 16.52892, -2.170203), "position": (9.748902, 6.942193, -18.87782), "is_moving_along_floor": false }
	current state: { "velocity": (-15.45897, 16.52892, -2.512219), "position": (9.508314, 6.942262, -18.95387), "is_moving_along_floor": false }
	error        : 0.25232231616974
	"""
	if !is_replay_enabled_:
		return
	var rng = RandomNumberGenerator.new()
	var arbitrarily_high_tick = 99999
	physics_state_per_tick[arbitrarily_high_tick] = {}
	var begin_state_client = { "velocity": Vector3(12.08496, 0.019526, -0.023346), "position": Vector3(23.16863, 2.500325, -26.49515), "is_moving_along_floor": true }
	var begin_state_server = { "velocity": Vector3(12.08496, 0.019526, -0.023346), "position": Vector3(23.16863, 2.500325, -26.49515), "is_moving_along_floor": true }
	var inputs = [
		{ "yaw": 331.5, "pitch": 4.55, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.5, "pitch": 4.65, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.5, "pitch": 4.75, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.5, "pitch": 4.85, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.5, "pitch": 5, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.45, "pitch": 5.1, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.4, "pitch": 5.2, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.35, "pitch": 5.3, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.25, "pitch": 5.4, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.15, "pitch": 5.5, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331.05, "pitch": 5.6, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 331, "pitch": 5.65, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 330.95, "pitch": 5.7, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 330.95, "pitch": 5.7, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 330.95, "pitch": 5.75, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 330.95, "pitch": 5.75, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 330.85, "pitch": 5.75, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) },
		{ "yaw": 330.65, "pitch": 5.85, "is_jumping": false, "is_slow_walking": false, "direction": Vector2(0, -1) }
	]
	var prior_simulated_state = { "velocity": Vector3(15.38109, 9.255051, -11.82438), "position": Vector3(27.31496, 2.811703, -27.95316), "is_moving_along_floor": true }
	var prior_predicted_state = { "velocity": Vector3(15.61088, 7.851548, -11.47076), "position": Vector3(27.3567, 2.681525, -27.87867), "is_moving_along_floor": true }
	var begin_state = begin_state_server
	var expected_state = prior_simulated_state
	var delta = 1.0 / 60
	for i in 1:
		if rng.randf() < 0.9:
			return
		var fuzz_size = 0.001
		var fuzzed_begin_state = begin_state.duplicate(true)
		fuzzed_begin_state.position += Vector3(rng.randf_range(-fuzz_size, fuzz_size), rng.randf_range(-fuzz_size, fuzz_size), rng.randf_range(-fuzz_size, fuzz_size))
		var sim_result = simulate({"tick": arbitrarily_high_tick, "state": fuzzed_begin_state}, inputs, expected_state, delta)
		var error_size = (sim_result.position - expected_state.position).length()
		if error_size > -0.1:
			print("err size: ", error_size)

func start_client():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(Network.DEFAULT_SERVER_IP, Network.PORT)
	if error: 
		return error
	multiplayer.multiplayer_peer = peer
	print("PEERS COUNT: ", multiplayer.get_peers().size())

func resize_window(index=0):
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	#get_window().size = Vector2(screen_size.x, screen_size.y)
	#get_window().position = Vector2(0, 0)
	get_window().size = Vector2(screen_size.x / 2.01, screen_size.y / 2)
	get_window().position = Vector2(index * (screen_size.x / 2), 0)

func print_replay_string(original_states):
	var states_to_print = original_states.duplicate()
	print("####### REPLAY START ######")
	print("var begin_state_client = ", convert_to_dict_literal(states_to_print.pop_front().state))
	print("var begin_state_server = ", convert_to_dict_literal(states_to_print.pop_front().state))
	print("var inputs = [")
	while states_to_print.size() > 3:
		print("\t", convert_to_dict_literal(states_to_print.pop_front()), ",")
		states_to_print.pop_front()
	print("\t", convert_to_dict_literal(states_to_print.pop_front()))
	print("]")
	print("var prior_simulated_state = ", convert_to_dict_literal(states_to_print.pop_front()))
	print("var prior_predicted_state = ", convert_to_dict_literal(states_to_print.pop_front()))
	print("####### REPLAY END ######")

func _handle_server_message(message: Dictionary):
	match message.type:
		Network.MessageType.RESIZE:
			resize_window(message["resize"])
		Network.MessageType.PLAYER_STATE:
			last_received_server_state = message
		Network.MessageType.PUPPET_STATE:
			puppets[message.puppet_id].add_state(message)

func _on_character_spawned(character: Node):
	var client_id = int(str(character.name))
	if client_id == multiplayer.get_unique_id():
		character_physics_state = character.starting_physics_state()
		client_character = character
	else:
		puppets[client_id] = character

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

static func convert_to_dict_literal(state_dict):
	var dict_literal = "{ "
	var items = []
	for key in state_dict:
		var value = state_dict[key]
		var value_in_gdscript_form
		if typeof(value) == TYPE_VECTOR3:
			value_in_gdscript_form = "Vector3%s" % value
		elif typeof(value) == TYPE_VECTOR2:
			value_in_gdscript_form = "Vector2%s" % value
		else:
			value_in_gdscript_form = str(value)
		items.append("\"%s\": %s" % [key, value_in_gdscript_form])
	dict_literal += ", ".join(items)
	dict_literal += " }"
	return dict_literal
