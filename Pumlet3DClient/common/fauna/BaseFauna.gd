extends KinematicBody

onready var body = $CollisionShape/Body

const max_health_color = Color("6eaa78")
const min_health_color = Color("9a4f50")

const health_default = 70
var health = health_default

var gravity = 15
var velocity = Vector3()
var direction = Vector3()
var look_dir = Vector3()
var speed = 8
var jump_prob = 0.4
var movement_enabled = true

var periodic_timer = Timer.new()
var rng = RandomNumberGenerator.new()

signal health_changed(new_health)
signal killed()

func _ready():
	rng.randomize()
	periodic_timer.connect("timeout", self, "_change_direction")
	periodic_timer.set_one_shot(true)
	add_child(periodic_timer)
	periodic_timer.start(rng.randf_range(0.5, 5))
	
	self.connect("health_changed", self, "_on_health_changed")
	self.connect("killed", self, "_on_killed")
	
	body.set_outline_color(max_health_color)

# ---------------------------------------------------------------------Hit Funcs

func hit(damage):
	health -= damage
	emit_signal("health_changed", health)
	if health < 0:
		emit_signal("killed")

func _on_health_changed(health):
	play_hitsound()
	color_outline(health)

func _on_killed():
	movement_enabled = false
	play_deathsound()
	queue_free()

func play_hitsound():
	var rand = rng.randf_range(0, 1)
	var sound_rsrc = null
	if rand > 0.8:
		sound_rsrc = load("res://common/fauna/assets/Pyro_paincrticialdeath03.wav")
	elif rand > 0.6:
		sound_rsrc = load("res://common/fauna/assets/Pyro_painsevere01.wav")
	elif rand > 0.4:
		sound_rsrc = load("res://common/fauna/assets/Pyro_painsevere02.wav")
	elif rand > 0.2:
		sound_rsrc = load("res://common/fauna/assets/Pyro_painsevere06.wav")
	else:
		sound_rsrc = load("res://common/fauna/assets/Pyro_painsharp03.wav")
	$AudioStreamPlayer3D.set_stream(sound_rsrc)
	$AudioStreamPlayer3D.play()

func color_outline(health):
	var health_prop : float = clamp(
		float(health) / health_default, 
		0.0, 
		1.0)
	body.set_outline_color(
		min_health_color.linear_interpolate(
			max_health_color, 
			health_prop))

func play_deathsound():
	$AudioStreamPlayer3D.set_stream(load("res://common/fauna/assets/yoshi-tongue.wav"))
	$AudioStreamPlayer3D.play()
	yield($AudioStreamPlayer3D, "finished")

# ----------------------------------------------------------------------Movement

var dash_ticks_dict = {}
func _physics_process(delta):
	if movement_enabled:
		velocity.y -= gravity * delta
		
		velocity = velocity.linear_interpolate(direction * speed, delta)
		
		rotate_towards_dir(delta)
		
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
				Vector3(),
				false,
				1,
				PI / 4,
				true),
			12 * delta)

func rotate_towards_dir(delta):
	if not look_dir == Vector3():
		look_at(transform.origin + look_dir, Vector3(0, 1, 0))
	look_dir = look_dir.linear_interpolate(direction, delta)

func dash(direction: Vector3, speed: float, ticks: int):
	dash_ticks_dict[direction * speed] = ticks

func _change_direction():
	direction = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	var rnum = rng.randf_range(0, 1)
	if rnum > 1 - jump_prob:
		dash(Vector3(0, 1, 0), 1.5, 10)
	periodic_timer.start(rng.randf_range(0.3, 2))
