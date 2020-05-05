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
var regen = 0
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
var ability_usable = {}
var cooldowns = {}
var abilities = {}

var character_under_my_control = false
var is_alive = true

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

# for debugging: this makes only network master able to control this character
# and sets global position to 0,0
func _ready():
	print("This is the character base class. Prepare muffin.")
	set_global_position(Vector2(0,0))
	character_under_my_control = is_network_master()
	
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

func get_input():
	# Detect up/down/left/right keystate and only move when pressed.
	# Continuous velocity makes prediction easier
	if character_under_my_control && is_alive:
		if Input.is_key_pressed(KEY_W) && is_on_floor():
			get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "up", []) 
			up()
		if Input.is_key_pressed(KEY_D):
			get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "right", [])
			right()
		if Input.is_key_pressed(KEY_A):
			get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "left", [])
			left()
		if Input.is_key_pressed(KEY_S):
			get_node("/root/ChubbyServer").send_player_rpc_unreliable(player_id, "down", [])
			down()

		# ability inputs to be handled separately to account for variable arguments
		# makes inheritance easier because players only need to redefine ability methods, not get_input 

# This function will be called by child classes within their _get_input function to:
# 1. call the ability with arguments passed in, tba at time of button press
# 2. tell the server the command given
# 3. 
func use_ability_and_notify_server_and_start_cooldown(ability_name, cooldown, args):
		# call the ability
		self.callv(ability_name, args)

		# for debugging
		print(parent.player_id + " activated ability: " + ability_name)

		# Tells server our player did the action and the arguments used
		get_node("/root/ChubbyServer").send_player_rpc(parent.player_id, ability_name, args)

		# Puts ability on cooldown
		parent.ability_usable[ability_name] = false
		add_and_return_timed_effect_exit(cooldown, "cooldown", ability_name)

func cooldown(ability):
	ability_usable[ability] = true

func label_debug(text):
	get_node("Label").set_text(text)

func _physics_process(delta):
	get_node("Label").set_text(str(health as int))
	get_child(1).position = get_child(0).position

	get_input()

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
	