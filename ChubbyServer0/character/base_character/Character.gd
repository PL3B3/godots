extends KinematicBody2D

var TimedEffect = preload("res://character/TimedEffect.tscn")

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
# type is the class of the character
var gravity2 = 0
var velocity = Vector2()
var rot_angle = -(PI / 2)
var facing = 0
var type = "base"
var ability_usable = [true, true, true]

func set_stats(speed, health_cap, health, regen):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health
	self.regen = regen

func _ready():
	print("This is the character base class. Prepare muffin.")

func add_and_return_timed_effect(time, effect, args, ps):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effect.init_timer(time, effect, args, ps)
	return timed_effect

func get_input():
	# Detect up/down/left/right keystate and only move when pressed.
	# Continuous velocity makes prediction easier

	if Input.is_key_pressed(KEY_W) && is_on_floor():
		print("up pressed")
		velocity.y -= 1.5 * speed
	if Input.is_key_pressed(KEY_D):
		if velocity.x <= 200:
			velocity.x += min(speed, 200 - velocity.x)
	if Input.is_key_pressed(KEY_A):
		if velocity.x >= -200:
			velocity.x -= min(speed, velocity.x + 200)
	if Input.is_key_pressed(KEY_S):
		velocity.y += 0.1 * speed

func cooldown(ability):
	ability_usable[ability] = true

func _physics_process(delta):
	get_node("Label").set_text(str(health as int))
	get_child(1).position = get_child(0).position

	# if we're hitting a surface
	if get_slide_count() > 0:
		# get one of the collisions, it's normal, and convert it into an angle
		var collision = get_slide_collision(get_slide_count() - 1)
		var collision_normal = collision.get_normal()
		rot_angle = collision_normal.angle()
		# if our current sprite rotation is off, we correct it.
		if abs(get_child(1).rotation - (rot_angle + PI / 2)) > 0.04:
			get_child(1).rotation += ((rot_angle + PI / 2) - (get_child(1).rotation)) * delta * rot_speed 

	if is_on_floor():
		velocity = Vector2()
		gravity2 = 0
	else:
		gravity2 += 9.8
	
	get_input()

	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0), false, 4, 0.9)

func hit(dam):
	health -= dam
	print("Was hit")
	if not health > 0:
		die()
		
func sayhi():
	print("hi")
	
func resetTimers():
	pass

func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	queue_free()

func ability0():
	pass

func ability1():
	pass
	
func ability2():
	pass

	