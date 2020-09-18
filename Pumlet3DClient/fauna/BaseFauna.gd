extends KinematicBody

var health_default = 2000
var health = health_default

var gravity = 15
var velocity = Vector3()
var direction = Vector3()
var speed = 16
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
		sound_rsrc = load("res://fauna/fauna_assets/Pyro_paincrticialdeath03.wav")
	elif rand > 0.6:
		sound_rsrc = load("res://fauna/fauna_assets/Pyro_painsevere01.wav")
	elif rand > 0.4:
		sound_rsrc = load("res://fauna/fauna_assets/Pyro_painsevere02.wav")
	elif rand > 0.2:
		sound_rsrc = load("res://fauna/fauna_assets/Pyro_painsevere06.wav")
	else:
		sound_rsrc = load("res://fauna/fauna_assets/Pyro_painsharp03.wav")
	$AudioStreamPlayer3D.set_stream(sound_rsrc)
	$AudioStreamPlayer3D.play()
	if health < 0:
		queue_free()
	#print(health)

func _physics_process(delta):
	if movement_enabled:
		velocity.y -= gravity * delta
		
		look_at(transform.origin + Vector3(velocity.x, 0, velocity.z), Vector3(0, 1, 0))
		velocity = velocity.linear_interpolate(direction * speed, delta)
		
		velocity = velocity.linear_interpolate(
			move_and_slide(
				velocity,
				Vector3.UP,
				true),
			12 * delta)

func dash(direction: Vector3, speed: float, ticks: int):
	var dash_ticks_remaining = ticks
	while dash_ticks_remaining > 0:
		velocity += direction.normalized() * speed * (float(dash_ticks_remaining) / ticks)
		yield(get_tree().create_timer(0.015),"timeout")
		dash_ticks_remaining -= 1

func _change_direction():
	direction = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	var rnum = rng.randf_range(0, 1)
	if rnum > 1 - jump_prob:
		dash(Vector3(0, 1, 0), 4, 5)
	periodic_timer.start(rng.randf_range(0.3, 2))
