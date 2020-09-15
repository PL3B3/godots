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

func fire():
	if can_fire and clip_remaining > 0 and ammo_remaining > 0:
		print("arms discharged")
		clip_remaining -= 1
		ammo_remaining -= 1
		can_fire = false
		if clip_remaining == 0:
			next_shot_timer.start(reload_time_default)
			#print("reloading")
		else:
			next_shot_timer.start(fire_rate_default)

func _load_next_shot():
	if clip_remaining == 0:
		clip_remaining = clip_size_default
	can_fire = true
