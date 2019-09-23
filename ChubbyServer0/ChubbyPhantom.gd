extends KinematicBody2D

var TimedEffect = preload("res://character/TimedEffect.tscn")

# float: speed is the character's movement speed
# float: health_cap defines the basic "max health" of a character, but overheal and boosts can change this
# float: health is actual current health
# float: regen is the amount of health to be added or removed per second from the character
# int: team is a letter representation of which team you are on
var speed = 200
var health_cap = 200
var health = 200
var regen = 2
var team = 'a'
var type = "base"
var timed_effects = []
var player_id
var time_scale = 1

# gravity2 is a workaround to physics simulation problems (I don't want to code a whole-ass momentum thing yet)
# It starts at 9.8 as a default
var gravity2 = 0
var velocity = Vector2(0,0)
var rot_angle = -(PI / 2)
var ability_usable = [true, true, true, true]
var physics_processing = false

func set_stats(speed, health_cap, health, regen):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health
	self.regen = regen

func set_id(id):
	self.player_id = id

#todo destroy timer upon completion
func add_and_return_timed_effect(time, effect, args, ps):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effects.push_back(timed_effect)
	timed_effect.init_timer(time, effect, args, ps)
	return timed_effect

func _physics_process(delta):
	#print(physics_processing)
	if (physics_processing):
		if get_slide_count() > 0:
			# get one of the collisions, it's normal, and convert it into an angle
			rot_angle = get_slide_collision(get_slide_count() - 1).get_normal().angle()
		move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0), false, 4, 0.9)
		
		if is_on_floor():
			velocity = Vector2()
			gravity2 = 0
		else:
			gravity2 += 9.8

		get_parent().send_updated_player_position_to_client_unreliable(player_id, get_global_position())
"""
func physics_single_execute(delta):
	if get_slide_count() > 0:
		# get one of the collisions, it's normal, and convert it into an angle
		rot_angle = get_slide_collision(get_slide_count() - 1).get_normal().angle()
	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0), false, 4, 0.9)
	
	if is_on_floor():
		velocity = Vector2()
		gravity2 = 0
	else:
		gravity2 += 9.8
"""

func cooldown(ability_num):
	ability_usable[ability_num] = true

func up():
	print("up called on chubbyphantom for player ", get_name())
	velocity.y -= 1.5 * speed
	
func down():
	velocity.y += 0.1 * speed
	
func left():
	if velocity.x >= -200:
		velocity.x -= min(speed, velocity.x + 200)
	else:
		velocity.x = -200

func right():
	if velocity.x <= 200:
		velocity.x += min(speed, 200 - velocity.x)
	else:
		velocity.x = 200

func hit(dam):
	health -= dam
	print("Was hit")
	if not health > 0:
		die()

func sayhi():
	print("hi, it's ", self)
	
func reset_timers():
	for effect in timed_effects:
		effect.reset_timer()

func accelerate_timers():
	for effect in timed_effects:
		effect.accelerate_timer()

func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	print("I died")

func ability0(arg_array):
	print("ability0 activated")

func ability1(arg_array):
	print("ability1 activated")
	
func ability2(arg_array):
	print("ability2 activated")
	
func ability3(arg_array):
	print("ability3 activated")