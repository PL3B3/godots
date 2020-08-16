extends KinematicBody2D

onready var parent = get_parent()
signal attribute_updated(attribute_name, value)
signal method_called(method_name, args)

# Dictionary of clients who we should transmit our updates to
# int (id), bool: yes or no sync
var clients_to_sync_with = {}

var damage = 15
var speed = 400
var velocity = Vector2()
var timer = null
var bullet_life = 4
var time_damage_factor = 9
var gravity = 3
var fired = false
var inflict_slow = false
var physics_processing = false

func _ready():
	self.connect("attribute_updated", get_node("/root/ChubbyServer"), "set_attribute", [parent.name + "/" + name])
	self.connect("method_called", get_node("/root/ChubbyServer"), "call_node_method_universal", [parent.name + "/" + name])
	# should not scan pickups
	$Sprite.modulate = parent.team_colors[parent.team]
	physics_processing = true

func on_timeout_complete():
	# remove self from player's object dictionary
	# print("Removing self: " + name)
	parent.call_and_sync("remove_object", [name])

func expand():
	$CollisionShape2D.set_scale(Vector2(3,3))
	$Sprite.set_scale(3 * $Sprite.get_scale())

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
	
	var noclip_time = (32.0 / speed) * (1 + 0.6 * int(parent.big_bean_mode))
	#print(str(noclip_time))
	yield(get_tree().create_timer(noclip_time), "timeout")
	set_collision_layer(parent.get_collision_layer())
	print(get_collision_layer())
	set_collision_mask(parent.get_collision_mask() - 128)
	print(get_collision_mask())

var counter = 0
func _physics_process(delta):
	if physics_processing:
		var collision = move_and_collide(velocity * delta)
		
		# every half second
		if counter == 45:
			# updates object on client side
			parent.server.update_position(parent.name + "/" + name, get_global_position() + (velocity * delta))
			#parent.send_updated_attribute(parent.name + "/" + name, "position", get_global_position())
			parent.send_updated_attribute(parent.name + "/" + name, "velocity", velocity)
			counter = 0
		
		counter += 1
		
		if fired:
			velocity.y += gravity
		if collision != null:
			print(str((1 + time_damage_factor * ((bullet_life - timer.time_left) / bullet_life)) * damage))
			if collision.collider.has_method("hit"):
				var time_damage_multiplier = 1 + time_damage_factor * ((bullet_life - timer.time_left) / bullet_life)
				collision.collider.emit_signal("method_called", "hit", [time_damage_multiplier * damage])
				if inflict_slow:
					collision.collider.emit_signal("attribute_updated", "speed_mult", 0.5)
					#collision.collider.add_and_return_timed_effect_exit("emit_signal", ["attribute_updated", "speed_mult", 1], 6)
					collision.collider.emit_signal("method_called", "add_and_return_timed_effect_exit", \
						["emit_signal", ["attribute_updated", "speed_mult", 1], 6])
				#collision.collider.hit(time_damage_multiplier * damage)
			# remove self from player's object dictionary
			on_timeout_complete()
