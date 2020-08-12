extends KinematicBody2D

onready var parent = get_parent()
var trail = preload("res://game_objects/fired_projectiles/BulletTrail.tscn")

var damage = 12
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
	set_collision_layer(parent.get_collision_layer())
	# should not scan pickups
	set_collision_mask(parent.get_collision_mask() - 128)
	$Sprite.modulate = parent.team_colors[parent.team]
	"""
	timer = Timer.new()
	timer.set_one_shot(true)
	timer.connect("timeout", self, "on_timeout_complete")
	timer.set_name("bullet_timer")
	add_child(timer)
	timer.start(bullet_life)
	"""
	physics_processing = true

func on_timeout_complete():
	# no behavior...removal determined by server
	if get_node("/root/ChubbyServer").offline:
		parent.remove_object(name)

func fire(center, radius, dir):
	rotation = dir
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(speed, 0).rotated(dir)
	fired = true
	#print("center at %s, position at %s, velocity is %s" % [center, position, velocity])

func expand():
	$CollisionShape2D.set_scale(Vector2(2,2))
	$Sprite.set_scale(2 * $Sprite.get_scale())

func _physics_process(delta):
	if physics_processing:
		#var trail_sprite = trail.instance()
		#trail_sprite.position = global_position
		#get_node("/root/ChubbyServer").add_child(trail_sprite)
		var collision = move_and_collide(velocity * delta)
		
		rotation = velocity.angle() + (PI / 2)
		
		if fired:
			velocity.y += gravity
		if collision != null:
			#print(damage * (1 + time_damage_factor * pow(((bullet_life - timer.time_left) / bullet_life), 2)))
			# Removal is fine if you're offline, for performance
			if get_node("/root/ChubbyServer").offline:
				parent.remove_object(name)
			# doesn't register a hit...that's determined by the server
			# no behavior...removal determined by server
			pass
