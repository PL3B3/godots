extends KinematicBody2D

onready var parent = get_parent()

var damage = 40
var velocity = Vector2()
var timer = null
var bullet_life = 3.5
var gravity = 7
var fired = false
var physics_processing = false

func _ready():
	set_collision_layer(parent.get_collision_layer())
	# should not scan pickups
	set_collision_mask(parent.get_collision_mask() - 128)
	$Sprite.modulate = parent.team_colors[parent.team]
	#timer = Timer.new()
	#timer.set_one_shot(true)
	#timer.start(bullet_life)
	#timer.connect("timeout", self, "on_timeout_complete")
	#timer.set_name("bullet_timer")
	#add_child(timer)
	physics_processing = true

func on_timeout_complete():
	# no behavior...removal determined by server
	pass
	
func fire(center, radius, dir):
	rotation = dir
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(600, 0).rotated(dir)
	fired = true
	#print("center at %s, position at %s, velocity is %s" % [center, position, velocity])

func _physics_process(delta):
	if physics_processing:
		var collision = move_and_collide(velocity * delta)
		
		if fired:
			velocity.y += gravity
		if collision:
			# Removal is fine if you're offline, for performance
			if get_node("/root/ChubbyServer").offline:
				parent.remove_object(name)
			# doesn't register a hit...that's determined by the server
			# no behavior...removal determined by server
			pass
