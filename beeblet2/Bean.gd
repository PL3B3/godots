extends KinematicBody2D

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var velocity = Vector2()
var damage = 20

# Called when the node enters the scene tree for the first time.
func fire(center, radius, dir):
	rotation = dir
	position = center + Vector2(radius, 0.0).rotated(dir)
	velocity = Vector2(750, 0).rotated(dir)

func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)
	if collision:
		if collision.collider.has_method("hit"):
			collision.collider.hit(damage)
		queue_free()

func _on_VisibilityNotifier2D_screen_exited():
	queue_free()
