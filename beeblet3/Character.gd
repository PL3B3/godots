extends KinematicBody2D

# this defines the speed at which a character model rotates to match its collided surface 
# this is purely visual
const rot_speed = 15

# float: speed is the character's movement speed
# float: health_cap defines the basic "max health" of a character, but overheal and boosts can change this
# float: health is actual current health
# float: regen is the amount of health to be added or removed per second from the character
# char: team is a letter representation of which team you are on
var speed
var health_cap
var health
var regen
var team

# gravity2 is a workaround to physics simulation problems (I don't want to code a whole-ass momentum thing yet)
# It starts at 9.8 as a default
var gravity2 = 0
var velocity = Vector2()
var rot_angle = -(PI / 2)
var facing = 0
var timer0 = null

func _init(speed, health_cap, health, regen):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health
	self.regen = regen

func _ready():
	print("This is the character base class. Prepare muffin.")
		
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
	if not health > 0:
		die()
		
func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	queue_free()
	
func ability0():
	pass

func ability1():
	pass
	
func ability2():
	pass

func _physics_process(delta):
	# get_node("Label").set_text(str(health as int))
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
	
	if velocity.x != 0 || velocity.y != 0:
		facing = velocity.angle()


#
class StatusEffect:
	var type
	var time
	
	func _init(t, tm):
		pass