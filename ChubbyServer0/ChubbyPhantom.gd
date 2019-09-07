extends KinematicBody2D

var TimedEffect = preload("res://character/TimedEffect.tscn")

# float: speed is the character's movement speed
# float: health_cap defines the basic "max health" of a character, but overheal and boosts can change this
# float: health is actual current health
# float: regen is the amount of health to be added or removed per second from the character
# int: team is a letter representation of which team you are on
var speed
var health_cap
var health
var regen
var team
var timed_effects = []

# gravity2 is a workaround to physics simulation problems (I don't want to code a whole-ass momentum thing yet)
# It starts at 9.8 as a default
var gravity2 = 0
var velocity = Vector2()
var rot_angle = -(PI / 2)
var ability_usable = [true, true, true, true]

func set_stats(speed, health_cap, health, regen):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health
	self.regen = regen

#todo destroy timer upon completion
func add_and_return_timed_effect(time, effect, args, ps):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effects.push_back(timed_effect)
	timed_effect.init_timer(time, effect, args, ps)
	return timed_effect

remote func cooldown(ability_num):
	ability_usable[ability_num] = true

#func _physics_process(delta):
#	physics_single_execute(delta)

func physics_single_execute(delta):
	if get_slide_count() > 0:
		# get one of the collisions, it's normal, and convert it into an angle
		rot_angle = get_slide_collision(get_slide_count() - 1).get_normal().angle()

	if is_on_floor():
		velocity = Vector2()
		gravity2 = 0
	else:
		gravity2 += 9.8

	move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2), Vector2(0.0, -1.0), false, 4, 0.9)
	print(position)

remote func up():
	velocity.y -= 1.5 * speed
	
remote func down():
	velocity.y += 0.1 * speed
	
remote func left():
	velocity.x -= speed
	
remote func right():
	velocity.x += speed

remote func hit(dam):
	health -= dam
	print("Was hit")
	if not health > 0:
		die()

remote func sayhi():
	print("hi, it's ", self)
	
remote func reset_timers():
	for effect in timed_effects:
		effect.reset_timer()

remote func accelerate_timers():
	for effect in timed_effects:
		effect.accelerate_timer()

remote func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	print("I died")

remote func ability0(arg_array):
	print("ability0 activated")

remote func ability1(arg_array):
	print("ability1 activated")
	
remote func ability2(arg_array):
	print("ability2 activated")
	
remote func ability3(arg_array):
	print("ability3 activated")