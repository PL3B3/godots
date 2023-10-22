extends Object
class_name PlayerPhysicsState

var _position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO

func _init(position: Vector3, velocity: Vector3):
	super()
	_position = position
	_velocity = velocity

func position():
	return _position

func velocity():
	return _velocity

