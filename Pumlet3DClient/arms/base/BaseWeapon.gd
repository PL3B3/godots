extends Spatial

export var fire_rate_default = 0.3
export var clip_size_default = 2
export var reload_time_default = 1.5
export var ammo_default = 20

var next_shot_timer = Timer.new()

var clip_remaining
var ammo_remaining
var can_fire = true

func _ready():
	clip_remaining = clip_size_default
	ammo_remaining = ammo_default
	next_shot_timer.connect("timeout", self, "_load_next_shot")
	next_shot_timer.set_one_shot(true)
	add_child(next_shot_timer)

func fire(fire_mode: int, fire_parameters):
	if can_fire and clip_remaining > 0 and ammo_remaining > 0:
		clip_remaining -= 1
		ammo_remaining -= 1
		var fire_dir = get_global_transform().basis.x.normalized()
		match fire_mode:
			0:
				primary_fire(fire_dir, fire_parameters)
			1: 
				secondary_fire(fire_dir, fire_parameters)
			2:
				tertiary_fire(fire_dir, fire_parameters)
			_:
				primary_fire(fire_dir, fire_parameters)
		can_fire = false
		if clip_remaining == 0:
			next_shot_timer.start(reload_time_default)
			#print("reloading")
		else:
			next_shot_timer.start(fire_rate_default)

func primary_fire(fire_dir: Vector3, fire_parameters):
	print("Fired weapon in primary mode")

func secondary_fire(fire_dir: Vector3, fire_parameters):
	print("Fired weapon in secondary mode")

func tertiary_fire(fire_dir: Vector3, fire_parameters):
	print("Fired weapon in tertiary mode")

func _load_next_shot():
	if clip_remaining == 0:
		clip_remaining = clip_size_default
	can_fire = true
