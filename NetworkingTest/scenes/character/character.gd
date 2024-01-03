extends Node

class_name Character

var FirstPersonDisplayScene = preload("res://scenes/character/first_person_display.tscn")
var MovementBodyScene = preload("res://scenes/movement/character_movement_kinematic_body.tscn")

var first_person_display_: FirstPersonDisplay
var movement_calculator_: CharacterMovementKinematicBody

var current_tick_: int = 0
var physics_state_per_tick_: Dictionary = {}
var inputs_: Dictionary = { -1: {"pitch": 0, "yaw": 0} }

func _init(position):
	first_person_display_ = FirstPersonDisplayScene.instantiate()
	movement_calculator_ = MovementBodyScene.instantiate()
	physics_state_per_tick_[0] = { "velocity": Vector3.ZERO, "position": position, "is_moving_along_floor": false }

func _ready():
	add_child(first_person_display_)
	add_child(movement_calculator_)

func display():
	first_person_display_.display(physics_state_per_tick_, inputs_[current_tick_ - 1])

func record_and_advance_state(input, tick):
	var next_physics_state = movement_calculator_.compute_next_physics_state(latest_state(), input)
	physics_state_per_tick_[tick + 1] = next_physics_state
	current_tick_ = tick + 1
	inputs_[tick] = input

func latest_state():
	return physics_state_per_tick_[current_tick_]

const RECONCILIATION_SNAP_IF_ABOVE = 10.25
const RECONCILIATION_SNAP_IF_BELOW = 0.001
const RECONCILIATION_VELOCITY_CORRECTION_FACTOR = 1.0
const RECONCILIATION_POSITION_CORRECTION_FACTOR = 0.15
const NO_SERVER_STATE = {"tick": -1}
var is_reconciliation_enabled_ = true
var last_received_server_state: Dictionary = NO_SERVER_STATE
var latest_handled_tick: int = 0
func reconcile_server_state(latest_server_message: Dictionary, delta: float):
	if is_reconciliation_enabled_ and latest_server_message["tick"] > latest_handled_tick:
		var inputs_since_state_tick = get_inputs_since_tick(latest_server_message.tick + 1)
		var predicted_state: Dictionary = latest_state()
		var simulated_state = simulate(latest_server_message, inputs_since_state_tick, predicted_state, delta)
		var position_error = simulated_state["position"] - predicted_state["position"]
		var velocity_error = simulated_state["velocity"] - predicted_state["velocity"]
		LogsAndMetrics.add_sample("sim_error", position_error.length())
		latest_handled_tick = latest_server_message["tick"]
		last_received_server_state = NO_SERVER_STATE
		if position_error.length() > RECONCILIATION_SNAP_IF_ABOVE or position_error.length() < RECONCILIATION_SNAP_IF_BELOW:
			physics_state_per_tick_[current_tick_] = simulated_state
		else:
			var corrected_state = predicted_state.duplicate()
			corrected_state.position = corrected_state.position.lerp(simulated_state.position, RECONCILIATION_POSITION_CORRECTION_FACTOR)
			corrected_state.velocity = corrected_state.position.lerp(simulated_state.velocity, RECONCILIATION_VELOCITY_CORRECTION_FACTOR)
			physics_state_per_tick_[current_tick_] = corrected_state

func simulate(latest_server_message: Dictionary, inputs_since_state_tick: Array, current_physics_state: Dictionary, delta: float):
#	print("blep")
	var states_to_print = []
	states_to_print.push_back(physics_state_per_tick_[latest_server_message.tick])
	# server state with tick X is from after input X has been processed. So next input is X+1 
	var simulation_state = latest_server_message.state
	states_to_print.push_back(latest_server_message)
	for simulation_input in inputs_since_state_tick:
		simulation_state = movement_calculator_.compute_next_physics_state(simulation_state, simulation_input)
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

func get_inputs_since_tick(initial_tick) -> Array:
	var tick = initial_tick
	var inputs_since_tick = []
	while inputs_.has(tick):
		inputs_since_tick.push_back(inputs_.get(tick))
		tick += 1
	return inputs_since_tick

"""
var CharacterMovementBodyScene = preload("res://scenes/movement/character_movement_kinematic_body.tscn")
var FirstPersonDisplayScene = preload("res://scenes/character/first_person_display.tscn")

var first_person_component_
var third_person_component_
var physics_move_component_
var states_ = []

func _init(first_person_component, third_person_component, physics_move_component, initial_state):
	first_person_component_ = first_person_component
	third_person_component_ = third_person_component
	physics_move_component_ = physics_move_component
	states_.append(initial_state)

static func make_player_character(initial_state):
	return Character.new(NoOpImplementation.new(), NoOpImplementation.new(), NoOpImplementation.new(), initial_state)

static func make_puppet_character(initial_state):
	return Character.new(NoOpImplementation.new(), NoOpImplementation.new(), NoOpImplementation.new(), initial_state)

static func make_server_character(initial_state):
	return Character.new(NoOpImplementation.new(), NoOpImplementation.new(), NoOpImplementation.new(), initial_state)

func _display_state():
	var state_to_display = states_[0] if states_.size() == 1 else interpolate_states_by_phys_frac(states_[-2], states_[-1])
	first_person_component_.first_person_display_state()
	third_person_component_.third_person_display_state()

func advance_state(physics_state, input):
	return physics_move_component_.compute_next_physics_state(physics_state, input)

func reconcile_state(server_snapshot):
	pass

func interpolate_states_by_phys_frac(state_1, state_2):
	return 0

func _ready():
	add_child(first_person_component_)
	add_child(third_person_component_)
	add_child(physics_move_component_)

class NoOpImplementation:
	func compute_next_physics_state(state):
		pass
	
	func first_person_display_state(physics_states, pitch, yaw):
		pass
	
	func third_person_display_state(state):
		pass
"""
