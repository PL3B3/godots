extends KinematicBody2D

onready var parent = get_parent()
signal attribute_updated(attribute_name, value)

var damage = 10
var speed = 435
var velocity = Vector2()
var timer = null
var bullet_life = 6
var time_damage_factor = 11
var gravity = 4
var fired = false
var inflict_slow = false
var physics_processing = false

func _ready():
	self.connect("attribute_updated", get_node("/root/ChubbyServer"), "set_attribute", [parent.name + "/" + name])
	set_collision_layer(parent.get_collision_layer())
	# should not scan pickups
	set_collision_mask(parent.get_collision_mask() - 128)
	$Sprite.modulate = parent.team_colors[parent.team]
	physics_processing = true

func on_timeout_complete():
	# remove self from player's object dictionary
	# print("Removing self: " + name)
	$bullet_timer.queue_free()
	parent.call_and_sync("remove_object", [name])

func fire(center, radius, dir):
	timer = Timer.new()
	timer.set_one_shot(true)
	add_child(timer)
	timer.start(bullet_life)
	timer.connect("timeout", self, "on_timeout_complete")
	timer.set_name("bullet_timer")
	rotation = dir
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(speed, 0).rotated(dir)
	fired = true

func _physics_process(delta):
	if physics_processing:
		var collision = move_and_collide(velocity * delta)
		
		# updates object on client side
		parent.server.update_position(parent.name + "/" + name, get_global_position() + (velocity * delta))
		#parent.send_updated_attribute(parent.name + "/" + name, "position", get_global_position())
		parent.send_updated_attribute(parent.name + "/" + name, "velocity", velocity)
		
		if fired:
			velocity.y += gravity
		if collision != null:
			if collision.collider.has_method("hit"):
				var time_damage_multiplier = 1 + time_damage_factor * ((bullet_life - timer.time_left) / bullet_life)
				collision.collider.emit_signal("method_called", "hit", [time_damage_multiplier * damage])
				if inflict_slow:
					collision.collider.emit_signal("attribute_updated", "speed_mult", 0.5)
					collision.collider.add_and_return_timed_effect_exit("emit_signal", ["attribute_updated", "speed_mult", 1], 6)
				#collision.collider.hit(time_damage_multiplier * damage)
			# remove self from player's object dictionary
			on_timeout_complete()
