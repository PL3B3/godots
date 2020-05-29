extends KinematicBody2D

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
	add_child(timer)
	physics_processing = true

func on_timeout_complete():
	queue_free()

func fire(center, radius, dir):
	rotation = dir
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(800, 0).rotated(dir)
	fired = true

func _physics_process(delta):
	if physics_processing:
		var collision = move_and_collide(velocity * delta)
		
		if fired:
			velocity.y += gravity
		if collision:
			if collision.collider.has_method("hit"):
				var time_damage_multiplier = log(bullet_life - timer.time_left)
				collision.collider.hit(time_damage_multiplier * damage)
			queue_free()


