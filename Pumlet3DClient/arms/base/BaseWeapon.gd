extends Spatial

onready var fire_point = $FirePoint
onready var interpolator = $Interpolator
var next_shot_timer = Timer.new()

var fire_rate_default = 0.3
var clip_size_default = 2
var reload_time_default = 1.5
var ammo_default = 20
var clip_remaining
var ammo_remaining
var can_fire = true

signal clip_changed()
signal reload_started()
signal dealt_damage(damage)


func _ready():
	next_shot_timer.connect("timeout", self, "_load_next_shot")
	next_shot_timer.set_one_shot(true)
	add_child(next_shot_timer)
	init()

func init():
	clip_remaining = clip_size_default
	ammo_remaining = ammo_default


func fire(fire_mode: int, fire_parameters):
	if can_fire and clip_remaining > 0 and ammo_remaining > 0:
		clip_remaining -= 1
		ammo_remaining -= 1
		var fire_transform = Transform()
		fire_transform.basis = get_global_transform().basis
		fire_transform.origin = get_global_transform().origin
		match fire_mode:
			0:
				primary_fire(fire_transform, fire_parameters)
			1: 
				secondary_fire(fire_transform, fire_parameters)
			2:
				tertiary_fire(fire_transform, fire_parameters)
			_:
				primary_fire(fire_transform, fire_parameters)
		can_fire = false
		if clip_remaining == 0:
			next_shot_timer.start(reload_time_default)
			emit_signal("reload_started")
		else:
			next_shot_timer.start(fire_rate_default)

func primary_fire(fire_transform: Transform, fire_parameters):
	print("Fired weapon in primary mode")

func secondary_fire(fire_transform: Transform, fire_parameters):
	print("Fired weapon in secondary mode")

func tertiary_fire(fire_transform: Transform, fire_parameters):
	print("Fired weapon in tertiary mode")

func _load_next_shot():
	if clip_remaining == 0 and ammo_remaining > 0:
		clip_remaining = min(clip_size_default, ammo_remaining)
	can_fire = true
	emit_signal("clip_changed")
