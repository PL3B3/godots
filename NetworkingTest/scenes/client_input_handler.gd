extends Node

class_name ClientInputHandler

const FULL_ROTATION_DEGREES = 360
const MOUSE_SENSITIVITY = 0.05

var _yaw = 0
var _pitch = 0
var input_per_tick = {}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if (event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		_yaw = normalize_angle_to_positive_degrees(_yaw - (event.relative.x) * MOUSE_SENSITIVITY)
		_pitch = clamp(_pitch - (event.relative.y * MOUSE_SENSITIVITY), -90.0, 90.0)
	elif event.is_action_pressed("toggle_mouse_mode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func record_input_for_tick(tick, delta):
	var input_frame = {
		"tick": tick,
		"yaw": _yaw,
		"pitch": _pitch,
		"delta": delta,
		"jump": Input.is_action_pressed("jump"),
		"direction": Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	}
	input_per_tick[tick] = input_frame
	return input_frame

func get_input_for_tick(tick):
	return input_per_tick[tick]

func normalize_angle_to_positive_degrees(angle: float):
	angle = fmod(angle, FULL_ROTATION_DEGREES)
	return angle + FULL_ROTATION_DEGREES if angle < 0 else angle
