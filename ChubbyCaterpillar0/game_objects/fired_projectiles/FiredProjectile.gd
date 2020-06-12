extends KinematicBody2D

onready var parent = get_parent()

var damage = 40
var velocity = Vector2()
var timer = null
var bullet_life = 10
var gravity = 10
var fired = false
var physics_processing = false

func _ready():
	timer = Timer.new()
	timer.set_one_shot(true)
	timer.start(bullet_life)
	timer.connect("timeout", self, "on_timeout_complete")
	timer.set_name("bullet_timer")
	add_child(timer)
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
			# doesn't register a hit...that's determined by the server
			print("we collided")
			# no behavior...removal determined by server