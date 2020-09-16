extends KinematicBody

var health = 2000

var gravity = 0.8
var velocity = Vector3()

func hit(damage):
	health -= damage
	print(health)

#func _physics_process(delta):
#	velocity.y -= gravity
#
#	velocity = velocity.linear_interpolate(0.5 * velocity, delta)
#
#	velocity = move_and_slide(
#		velocity,
#		Vector3.UP,
#		true)

func dash(direction: Vector3, speed: float, ticks: int):
	var dash_ticks_remaining = ticks
	while dash_ticks_remaining > 0:
		velocity += direction.normalized() * speed * (float(dash_ticks_remaining) / ticks)
		yield(get_tree().create_timer(0.015),"timeout")
		dash_ticks_remaining -= 1
