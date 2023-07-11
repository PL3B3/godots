extends Object
class_name PlayerPhysicsState

var __transform: Transform3D = Transform3D.IDENTITY
var __linear_velocity: Vector3 = Vector3.ZERO
var __tick: int = 0

func _init(transform: Transform3D, linear_velocity: Vector3, tick: int):
	super()
	__transform = transform
	__linear_velocity = linear_velocity
	__tick = tick

func get_transform():
	return Transform3D(__transform)

func get_linear_velocity():
	return Vector3(__linear_velocity)

func get_tick():
	return __tick
