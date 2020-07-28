extends KinematicBody2D

onready var parent = get_parent()

var damage = 40
var velocity = Vector2()
var timer = null
var bullet_life = 4
var gravity = 7
var fired = false
var physics_processing = false

func _ready():
	set_collision_layer(parent.get_collision_layer())
	# should not scan pickups
	set_collision_mask(parent.get_collision_mask() - 128)
	$Sprite.modulate = parent.team_colors[parent.team]
	timer = Timer.new()
	timer.set_one_shot(true)
	add_child(timer)
	timer.start(bullet_life)
	timer.connect("timeout", self, "on_timeout_complete")
	timer.set_name("bullet_timer")
	physics_processing = true

func on_timeout_complete():
	# remove self from player's object dictionary
	# print("Removing self: " + name)
	$bullet_timer.queue_free()
	parent.call_and_sync("remove_object", [name])

func fire(center, radius, dir):
	rotation = dir
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(800, 0).rotated(dir)
	fired = true

func _physics_process(delta):
	if physics_processing:
		var collision = move_and_collide(velocity * delta)
		
		# updates object on client side 
		parent.send_updated_attribute(parent.name + "/" + name, "position", position)
		parent.send_updated_attribute(parent.name + "/" + name, "velocity", velocity)
		
		if fired:
			velocity.y += gravity
		if collision:
			if collision.collider.has_method("hit"):
				var time_damage_multiplier = log(3 + (2.5 * (bullet_life - timer.time_left)))
				collision.collider.hit(time_damage_multiplier * damage)
			# remove self from player's object dictionary
			on_timeout_complete()
