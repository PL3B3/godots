extends Node3D

class_name ThirdPersonDisplay

var states_: Array = []
var displayed_state_: Dictionary

func _ready():
	displayed_state_ = {"position": global_position, "rotation": Quaternion.IDENTITY}
	states_.append_array([displayed_state_, displayed_state_])

func _process(delta):
	display()

func display():
	var phys_frame_interpolated_state = lerp_between_states_(states_[-2], states_[-1], Engine.get_physics_interpolation_fraction())
	displayed_state_ = lerp_between_states_(displayed_state_, phys_frame_interpolated_state, 0.8)
	global_position = phys_frame_interpolated_state.position
	global_basis = Basis(phys_frame_interpolated_state.rotation)

func add_state(state):
	var euler_rotation_as_vector = Vector3(deg_to_rad(state.pitch), deg_to_rad(state.yaw), 0)
	var display_state = {
		"position": state.position,
		"rotation": Quaternion(Basis.from_euler(euler_rotation_as_vector))
	}
	states_.append(display_state)

static func lerp_between_states_(from_state, to_state, lerp_factor=0.5):
	# TODO slerp rotation can cause wonky angles because it doesn't preserve pure Y -> X -> Z rotation order
	return {
		"position": from_state.position.lerp(to_state.position, lerp_factor),
		"rotation": from_state.rotation.slerp(to_state.rotation, lerp_factor)
	}

static func is_puppet():
	return true
