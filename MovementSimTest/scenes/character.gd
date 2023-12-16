extends RigidBody3D

const SIM_TICKS = 10
const ERROR_MARGIN = 0.0001
const VELOCITY_CHANGE_TICKS = 15

const VELOCITY_KEY = "velocity"
const TRANSFORM_KEY = "transform"
const TICK_KEY = "tick"

@onready var physics_fps = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
@onready var tick_limit: int = 60 * 10 * physics_fps

var speed = 100.0
var acceleration = 1.0
var game_tick: int = 0
var state_history: Array = []
var errors: Array[float] = []


func _ready():
	state_history.push_back({TRANSFORM_KEY: global_transform, VELOCITY_KEY: linear_velocity, TICK_KEY: game_tick})



func _integrate_forces(state):
	pass


func _physics_process(delta):
	if game_tick == tick_limit:
		errors.sort()
		print(errors.slice(-50))
		get_tree().quit()
	game_tick += 1
	var state_at_frame_begin = current_state()
	var simulated_state = simulate(delta)
	var position_error = (simulated_state[TRANSFORM_KEY].origin - state_at_frame_begin[TRANSFORM_KEY].origin).length()
	print(position_error)
	errors.push_back(position_error)
	reset_state_to_before_simulation(state_at_frame_begin)
	state_history.push_back(state_at_frame_begin)


func update_state(initial_state: Dictionary):
	linear_velocity = calculate_random_velocity(initial_state) # Vector3.FORWARD * 0.5 # 
	global_transform = initial_state[TRANSFORM_KEY]
	force_update_transform()


func calculate_random_velocity(state: Dictionary):
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state[TICK_KEY] / VELOCITY_CHANGE_TICKS)
	return speed * Vector3(
		rng.randf_range(-1, 1),
		rng.randf_range(-1, 1),
		rng.randf_range(-1, 1)
	)


func calculate_back_forth_velocity(state: Dictionary):
	return Vector3.FORWARD if sin(state[TICK_KEY] * physics_fps) > 0 else Vector3.BACK


func simulate(delta):
	if len(state_history) < SIM_TICKS:
		return current_state()
	var recorded_states: Array = state_history.slice(-SIM_TICKS)
	global_transform = state_history[-SIM_TICKS][TRANSFORM_KEY]
	for past_state in recorded_states:
		var sim_state = {TRANSFORM_KEY: global_transform, VELOCITY_KEY: Vector3.ZERO, TICK_KEY: past_state[TICK_KEY]}
		update_state(sim_state)
#		PhysicsServer3D.simulate(delta)
	return {TRANSFORM_KEY: global_transform, VELOCITY_KEY: linear_velocity, TICK_KEY: state_history.back()[TICK_KEY]}


func current_state():
	return {TRANSFORM_KEY: global_transform, VELOCITY_KEY: linear_velocity, TICK_KEY: game_tick}


func reset_state_to_before_simulation(state_before_simulation):
	update_state(state_before_simulation)
