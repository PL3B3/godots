extends KinematicBody

var health = 2000

var gravity = 5
var velocity = Vector3()
var direction = Vector3()
var speed = 4
var movement_enabled = true

var periodic_timer = Timer.new()
var rng = RandomNumberGenerator.new()

func _ready():
	periodic_timer.connect("timeout", self, "_change_direction")
	periodic_timer.set_one_shot(true)
	add_child(periodic_timer)
	periodic_timer.start(rng.randf_range(0.5, 5))


func hit(damage):
	health -= damage
	#print(health)

func _physics_process(delta):
	if movement_enabled:
		velocity.y -= gravity * delta
		
		velocity = velocity.linear_interpolate(direction * speed, 2 * delta)
		
		velocity = move_and_slide(
			velocity,
			Vector3.UP,
			true)

func dash(direction: Vector3, speed: float, ticks: int):
	var dash_ticks_remaining = ticks
	while dash_ticks_remaining > 0:
		velocity += direction.normalized() * speed * (float(dash_ticks_remaining) / ticks)
		yield(get_tree().create_timer(0.015),"timeout")
		dash_ticks_remaining -= 1

func _change_direction():
	direction = Vector3(rng.randf_range(-1, 1), rng.randf_range(-3, 3), 0).normalized()
	var rnum = rng.randf_range(0, 1)
	if rnum > 0.9:
		dash(Vector3(0, 1, 0), 3, 10)
	periodic_timer.start(rng.randf_range(0.3, 2))
