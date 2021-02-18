extends Area

signal body_hit(body, dist_ratio)
signal explosion_finished()
var checking_bodies = false
var area_radius = 6
var compensation_radius = 1

func _ready():
	$Shape.shape.radius = area_radius

func setup(mask, origin):
	#collision_layer = layer
	collision_mask = mask
	#set_collision_mask_bit(8, true)
	get_global_transform().origin = origin

func explode():
	checking_bodies = true
	animate_explosion()

func animate_explosion():
	print("animated")
	$Smoke.emitting = true
	$Shards.emitting = true
	start_end_timer()

func start_end_timer():
	var animation_timer = Timer.new()
	animation_timer.set_one_shot(true)
	animation_timer.connect("timeout", self, "remove")
	add_child(animation_timer)
	animation_timer.start(3.8)

func remove():
	emit_signal("explosion_finished")
	queue_free()

func _physics_process(delta):
	if checking_bodies:
		for body in get_overlapping_bodies():
			emit_signal(
				"body_hit", 
				body,
				((
					body.get_global_transform().origin - 
					get_global_transform().origin).length() - 
					2) / 
				area_radius)
		checking_bodies = false
