extends KinematicBody2D

# Base class for multiplayer-oriented character

# Preloaded resources

var TimedEffect = preload("res://character/TimedEffect.tscn")


# general player stats

# float: speed is the character's movement speed
# float: health_cap defines the basic "max health" of a character, but overheal and boosts can change this
# float: health is actual current health
# float: regen is the amount of health to be added or removed per second from the character
# char: team is a letter representation of which team you are on
var speed = 200
var health_cap = 200
var health = 200
var regen = 0
var team = 'a'
var is_alive = true
var timed_effects = []

# for physics and visual

# gravity2 is a workaround to physics simulation problems (I don't want to code a whole-ass momentum thing yet)
# It starts at 9.8 as a default 
# type is the class of the character
var gravity2 = 0
var velocity = Vector2(0,0)
var rot_angle = -(PI / 2)
var facing = 0
const rot_speed = 15

# tracks if an ability is on cooldown

# I picked an arbitrary order
# 0: mouse_ability_0
# 1: mouse_ability_1
# 2: key_ability_0
# 3: key_ability_1
# 4: key_ability_2
var ability_usable = [true, true, true, true, true]
var cooldowns = []

# for multiplayer

var player_id
var type = "base"
# only turned true when
var character_under_my_control = false
# Incremented every time child object is spawned
# Each child object is named [player_id]-[this number]
# Example: player id is 3000123, this counter is 5, 
# then the object is: "3000123-5" as a STRING
var object_id_counter = 0
var physics_processing = false

func set_stats_default():
	health = health_cap

func set_stats(speed, health_cap, regen, xy, player_id):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health_cap
	self.regen = regen
	self.player_id = player_id
	set_global_position(xy)

func set_id(id):
	self.player_id = id

# for debugging
# sets global position to 0,0
func _ready():
	print("This is the character base class on the server side")
	set_global_position(Vector2(0,0))
	
#func old_add_and_return_timed_effect(time, effect, args, ps):
#	var timed_effect = TimedEffect.instance()
#	add_child(timed_effect)
#	timed_effect.init_timer(time, effect, args, ps)
#	timed_effects.push_back(timed_effect)
	
func add_and_return_timed_effect_full(time, enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effect.init_timer(time, enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats)
	timed_effects.push_back(timed_effect)

func add_and_return_timed_effect_exit(time, exit_func, exit_args):
	add_and_return_timed_effect_full(time, "", [], "", [], exit_func, exit_args, 1)

func add_and_return_timed_effect_body(time, body_func, body_args, repeats):
	add_and_return_timed_effect_full(time, "", [], body_func, body_args, "", [], repeats)

# 1. call the ability with arguments passed in, tba at time of button press
# 2. tell the server the command given
# 3. activate cooldown timer
func use_ability_and_notify_server_and_start_cooldown(ability_name, cooldown, args):
		# call the ability
		callv(ability_name, args)

		# for debugging
#		print(str(player_id) + " activated ability: " + ability_name)

		# Tells server our player did the action and the arguments used
		get_node("/root/ChubbyServer").send_player_rpc(player_id, ability_name, args)

		# Puts ability on cooldown
		ability_usable[ability_name] = false
		add_and_return_timed_effect_exit(cooldown, "cooldown", ability_name)

func cooldown(ability):
	ability_usable[ability] = true

func label_debug(text):
	get_node("Label").set_text(text)

func _physics_process(delta):
	get_node("Label").set_text(str(health as int))
	get_child(1).position = get_child(0).position

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

		get_parent().send_server_rpc_to_all_players_unreliable("parse_server_rpc", "parse_updated_player_position_from_server", player_id, get_global_position())
#		get_parent().send_updated_player_position_to_client_unreliable(player_id, get_global_position())

func hit(dam):
	health -= dam
	print("Was hit")
	if not health > 0:
		die()
		
func sayhi():
	print("hi")
	
func reset_timers():
	for effect in timed_effects:
		effect.reset_timer()

func accelerate_timers():
	for effect in timed_effects:
		effect.accelerate_timer()

func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	print("I died")
	add_and_return_timed_effect_body(1, "ascend", [], 8)
	is_alive = false
	add_and_return_timed_effect_exit(20, "respawn", [])
	# queue_free()

func respawn():
	set_stats_default()
	is_alive = true

func ascend():
	print("ascending")
	gravity2 = -400

func up():
	velocity.y -= 1.5 * speed

func down():
	velocity.y += 0.1 * speed

func right():
	if velocity.x <= speed:
		velocity.x += min(speed, speed - velocity.x)
	else:
		velocity.x = speed

func left():
	if velocity.x >= -speed:
		velocity.x -= min(speed, velocity.x + speed)
	else:
		velocity.x = -speed

func mouse_ability_0(mouse_pos):
	pass

func mouse_ability_1(mouse_pos):
	pass

func key_ability_0():
	print("key_ability_0 activated on player: " + str(player_id))
	pass

func key_ability_1():
	print("yohoho")
	pass

func key_ability_2():
	pass