extends KinematicBody2D

var speed = 400

var BeanStance = preload("res://Bean.tscn")

var gravity2 = 9.8
var velocity = Vector2()
var rot_angle = -(PI / 2)
var rot_speed = 15

func get_input():
	# Detect up/down/left/right keystate and only move when pressed.
	
	if Input.is_action_pressed('ui_up') && is_on_floor():
#		print("up pressed")
		velocity.y -= 1.5 * speed
	if Input.is_action_pressed('ui_right'):
		velocity.x += speed
	if Input.is_action_pressed('ui_left'):
		velocity.x -= speed
	if Input.is_action_pressed('ui_down'):
		velocity.y += 0.1 * speed
	
	if Input.is_mouse_button_pressed(BUTTON_LEFT):
		pull_og()
#		print("mouse clicked")

func pull_og():
	#creates and fires bean bullet. the expression which represents angle to mouse is finicky. trust it
	var beenis = BeanStance.instance()
#	print("fired")
	beenis.fire(get_child(0).global_position, 95, get_global_mouse_position().angle_to_point(get_child(0).global_position))
	get_parent().add_child(beenis)
	
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
	
#	print(position)
	
	get_input()

	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0))