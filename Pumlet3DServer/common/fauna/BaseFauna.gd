extends KinematicBody

var health_default = 120
var health = health_default

var gravity = 15
var velocity = Vector3()
var direction = Vector3()
var speed = 10
var jump_prob = 0.4
var movement_enabled = true

var periodic_timer = Timer.new()
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	periodic_timer.connect("timeout", self, "_change_direction")
	periodic_timer.set_one_shot(true)
	add_child(periodic_timer)
	periodic_timer.start(rng.randf_range(0.5, 5))


func hit(damage):
	health -= damage
	var rand = rng.randf_range(0, 1)
	$HealthLight.set_color(Color(1 - (health / health_default), health / health_default, 0.3))
	var sound_rsrc = null
	if rand > 0.8:
		sound_rsrc = load("res://assets/fauna_assets/Pyro_paincrticialdeath03.wav")
	elif rand > 0.6:
		sound_rsrc = load("res://assets/fauna_assets/Pyro_painsevere01.wav")
	elif rand > 0.4:
		sound_rsrc = load("res://assets/fauna_assets/Pyro_painsevere02.wav")
	elif rand > 0.2:
		sound_rsrc = load("res://assets/fauna_assets/Pyro_painsevere06.wav")
	else:
		sound_rsrc = load("res://assets/fauna_assets/Pyro_painsharp03.wav")
	$AudioStreamPlayer3D.set_stream(sound_rsrc)
	$AudioStreamPlayer3D.play()
	if health < 0:
		movement_enabled = false
		$AudioStreamPlayer3D.set_stream(load("res://assets/fauna_assets/yoshi-tongue.wav"))
		$AudioStreamPlayer3D.play()
		yield($AudioStreamPlayer3D, "finished")
		queue_free()
	#print(health)

var dash_ticks_dict = {}
func _physics_process(delta):
	if movement_enabled:
		velocity.y -= gravity * delta
		
		if not Vector3(velocity.x, 0, velocity.z) == Vector3():
			look_at(transform.origin + Vector3(velocity.x, 0, velocity.z), Vector3(0, 1, 0))
		velocity = velocity.linear_interpolate(direction * speed, delta)
		
		for dash_vector in dash_ticks_dict:
			var ticks_left = dash_ticks_dict[dash_vector]
			if ticks_left > 0:
				velocity += dash_vector
				dash_ticks_dict[dash_vector] -= 1
			else:
				dash_ticks_dict.erase(dash_vector)
		
		velocity = velocity.linear_interpolate(
			move_and_slide(
				velocity,
				Vector3.UP,
				true),
			12 * delta)

func dash(direction: Vector3, speed: float, ticks: int):
	dash_ticks_dict[direction * speed] = ticks

func _change_direction():
	direction = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	var rnum = rng.randf_range(0, 1)
	if rnum > 1 - jump_prob:
		dash(Vector3(0, 1, 0), 1.5, 10)
	periodic_timer.start(rng.randf_range(0.3, 2))
