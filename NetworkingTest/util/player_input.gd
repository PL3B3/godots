extends Object
class_name PlayerInput

var _yaw: Vector3
var _pitch: Vector3
var _is_jumping: bool
var _direction: Vector2

func _init(yaw: Vector3, pitch: Vector3, is_jumping: bool, direction: Vector2):
	super()
	_yaw = yaw
	_pitch = pitch
	_is_jumping = is_jumping
	_direction = direction

func yaw():
	return _yaw

func pitch():
	return _pitch

func is_jumping():
	return _is_jumping

func direction():
	return _direction

func serialize() -> Dictionary:
	return {
		"yaw": _yaw,
		"pitch": _pitch,
		"is_jumping": _is_jumping,
		"direction": _direction
	}

func deserialize(serialized_data: Dictionary) -> PlayerInput:
	return PlayerInput.new(
		serialized_data["yaw"],
		serialized_data["pitch"],
		serialized_data["is_jumping"],
		serialized_data["direction"]
	)
	
