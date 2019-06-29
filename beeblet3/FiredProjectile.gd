extends KinematicBody2D

var damage
var velocity = Vector2()
var timer = null
var bullet_life = 10
var gravity
var fired = false

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
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(800, 0).rotated(dir)
	fired = true
	
func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)
	
	if fired:
		velocity.y += gravity
	if collision:
		if collision.collider.has_method("hit"):
			collision.collider.hit(damage)
		queue_free()
