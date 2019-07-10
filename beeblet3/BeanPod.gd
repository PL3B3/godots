extends KinematicBody2D

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var velocity = Vector2()
var timer = null
var bullet_life = 3
var fired = false
var gravity = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	timer = Timer.new()
	timer.set_one_shot(true)
	timer.start(bullet_life)
	timer.connect("timeout", self, "on_timeout_complete")
	add_child(timer)

func on_timeout_complete():
	queue_free()
	
func fire(center, radius, dir):
	rotation = dir
	
	#this whole cannonoffset shenanigan represents how far the bullet rotation is from the perfect upward bullet. 
	#THis is the ideal angle we strive towards, delivering max damage, etc, based on skill
	var cannon_offset = 0
	if rotation <= 0:
		cannon_offset = abs(rotation + (PI / 2))
	else:
		cannon_offset = (PI / 2) + abs(rotation - (PI / 2))
	
	cannon_offset = 1 / (1 + cannon_offset)
	
	gravity = 8
#	gravity = 10 / cannon_offset
	
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(400, 0).rotated(dir)
#	velocity = Vector2(1200 * cannon_offset, 0).rotated(dir)
	fired = true

#func normalize(a):
#	if a >= 0:
#		return a
#	else:
#		return 2 * PI - abs(a)

func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)
	
	if fired:
		velocity.y += gravity
	if collision:
		if collision.collider.has_method("hit"):
			var dam = 60 + ((bullet_life - timer.get_time_left()) * (bullet_life - timer.get_time_left())) * 90
			print("dam is: ", dam)
			collision.collider.hit(dam)
		queue_free()
		
	rotation = velocity.angle()

func _on_VisibilityNotifier2D_screen_exited():
#	queue_free()
	pass