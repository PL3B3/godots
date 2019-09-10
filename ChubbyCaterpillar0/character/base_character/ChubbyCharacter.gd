extends KinematicBody2D

# base class for multiplayer-oriented character

var TimedEffect = preload("res://character/TimedEffect.tscn")

# this defines the speed at which a character model rotates to match its collided surface 
# this is purely visual
const rot_speed = 15

# float: speed is the character's movement speed
# float: health_cap defines the basic "max health" of a character, but overheal and boosts can change this
# float: health is actual current health
# float: regen is the amount of health to be added or removed per second from the character
# char: team is a letter representation of which team you are on
var speed = 200
var health_cap = 200
var health = 200
var regen = 2
var team = 'a'
var player_id

# gravity2 is a workaround to physics simulation problems (I don't want to code a whole-ass momentum thing yet)
# It starts at 9.8 as a default
# type is the class of the character
var gravity2 = 0
var velocity = Vector2(0,0)
var rot_angle = -(PI / 2)
var facing = 0
var type = "base"
var timed_effects = []
var ability_usable = [true, true, true, true]

func set_stats(speed, health_cap, regen, xy, player_id):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health_cap
	self.regen = regen
	self.player_id = player_id
	set_global_position(xy)

func _ready():
	print("This is the character base class. Prepare muffin.")

func add_and_return_timed_effect(time, effect, args, ps):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effect.init_timer(time, effect, args, ps)
	timed_effects.push_back(timed_effect)
	return timed_effect

func get_input():
	# Detect up/down/left/right keystate and only move when pressed.
	# Continuous velocity makes prediction easier

	if Input.is_key_pressed(KEY_W) && is_on_floor():
		velocity.y -= 1.5 * speed
		get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "up", []) 
	if Input.is_key_pressed(KEY_D):
		if velocity.x <= 200:
			velocity.x += min(speed, 200 - velocity.x)
			get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "right", [])
		else:
			velocity.x = 200
	if Input.is_key_pressed(KEY_A):
		if velocity.x >= -200:
			velocity.x -= min(speed, velocity.x + 200)
			get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "left", [])
		else:
			velocity.x = -200
	if Input.is_key_pressed(KEY_S):
		velocity.y += 0.1 * speed
		get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "down", [])

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

	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0), false, 4, 0.9)

	if is_on_floor():
		velocity = Vector2()
		gravity2 = 0
	else:
		gravity2 += 9.8
	
	get_input()

	

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

	