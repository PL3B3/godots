extends Node

class_name Character

var FirstPersonDisplayScene = preload("res://scenes/character/first_person_display.tscn")
var MovementBodyScene = preload("res://scenes/movement/character_movement_kinematic_body.tscn")

var first_person_display_: FirstPersonDisplay
var movement_calculator_: CharacterMovementKinematicBody

var states_ = []

func _init(initial_state):
	first_person_display_ = FirstPersonDisplayScene.instantiate()
	movement_calculator_ = MovementBodyScene.instantiate()
	states_.append(initial_state)

func _ready():
	add_child(first_person_display_)
	add_child(movement_calculator_)

func display():
	first_person_display_.first_person_display_state(states_, 0, 0)

func record_and_advance_state(physics_state, input):
	var next_physics_state = movement_calculator_.compute_next_physics_state(physics_state, input)
	states_.append(next_physics_state)

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
