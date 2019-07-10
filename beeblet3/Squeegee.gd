extends KinematicBody2D

var speed = 200

var Toe = preload("res://Toe.tscn")

var gravity2 = 9.8
var velocity = Vector2()
var rot_angle = -(PI / 2)
var rot_speed = 15
var health = 200
var facing = 0
var toe_delay = 0.5
var timer = null
var can_toe = true

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
	if Input.is_key_pressed(KEY_E) && can_toe:
		extend_toe()
		timer = Timer.new()
		timer.set_one_shot(true)
		timer.start(toe_delay)
		timer.connect("timeout", self, "on_timeout_complete")
		add_child(timer)
		can_toe = false
		
func on_timeout_complete():
	can_toe = true

func extend_toe():
	var toe = Toe.instance()
	toe.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.1, facing)
	get_parent().add_child(toe)
	
func hit(dam):
	health -= dam
	if not health > 0:
		queue_free()
		
	print(Vector2(1,1).angle())

	
func _physics_process(delta):
	get_node("Label").set_text(str(health as int))
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
		gravity2 += speed / 40
	
	get_input()

	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0))
	
	if velocity.x != 0 || velocity.y != 0:
		facing = velocity.angle()