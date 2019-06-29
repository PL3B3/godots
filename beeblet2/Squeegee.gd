extends KinematicBody2D

var speed = 400

var gravity2 = 9.8
var velocity = Vector2()
var rot_angle = -(PI / 2)
var rot_speed = 15
var health = 100

func _ready():
	print("Destroy this little BOI whomst health at: ", health)

func get_input():
	# Detect up/down/left/right keystate and only move when pressed.

	if Input.is_key_pressed(KEY_W) && is_on_floor():
#		print("up pressed")
		velocity.y -= 1.5 * speed
	if Input.is_key_pressed(KEY_D):
		velocity.x += speed
	if Input.is_key_pressed(KEY_A):
		velocity.x -= speed
	if Input.is_key_pressed(KEY_S):
		velocity.y += 0.1 * speed

func hit(dam):
	health -= dam
	if health > 20:
		print("OWO! OWO! My Hewfh Points Is At: ", health)
	else:
		print("OWO! I am cwose to def! I am DIE!")
		
func _process(delta):
	if health <= 0:
		queue_free()
	
func _physics_process(delta):
	get_child(1).position = get_child(0).position
	
	velocity.x = 0
	
	if get_slide_count() > 0:
		var collision = get_slide_collision(get_slide_count() - 1)
		var collision_normal = collision.get_normal()
		rot_angle = collision_normal.angle()
		if abs(get_child(1).rotation - (rot_angle + PI / 2)) > 0.04:
			get_child(1).rotation += ((rot_angle + PI / 2) - (get_child(1).rotation)) * delta * rot_speed 
	
	if is_on_floor():
		velocity = Vector2()
		gravity2 = 0
	else:
		gravity2 += 9.8
	
	get_input()

	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0))