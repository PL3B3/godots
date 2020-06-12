extends KinematicBody2D
# 扭曲树

# base class for multiplayer-oriented character


##
## Preloaded resources
##

onready var client = get_node("/root/ChubbyServer")
onready var uuid_generator = client.client_uuid_generator
onready var Interpolator = get_node("/root/ChubbyServer/Interpolator")
var TimedEffect = preload("res://character/TimedEffect.tscn")

##
## general player stats
##

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

##
## for physics and visual
##


var gravity2 := 0.0 # a workaround to enable directional acceleration, It starts at 9.8 as a default
var velocity := Vector2(0,0) # Vector2: velocity tracks player movement
var rot_angle = -(PI / 2) # float: rot_angle is used to orient the player perpendicular to collision normal
var facing = 0
const rot_speed = 15

##
## tracks if an ability is on cooldown
##

# I picked an arbitrary order
# 0: mouse_ability_0
# 1: mouse_ability_1
# 2: key_ability_0
# 3: key_ability_1
# 4: key_ability_2
var ability_usable = [true, true, true, true, true]
var cooldowns = [10, 10, 10, 10, 10]
# Used to convert between ability name and its index in the ability_usable array
const ability_conversions = {
	"mouse_ability_0" : 0,
	"mouse_ability_1" : 1, 
	"key_ability_0" : 2, 
	"key_ability_1" : 3, 
	"key_ability_2" : 4
}

##
## for multiplayer
##

# decimal: player_id is the unique network id of the player
# string: type is the class of the character
# boolean: character_under_my_control marks if this is client's player
# decimal: object_id_counter is incremented every time child object is spawned
# 	Each child object is named its id
var player_id
var type = "base"
var character_under_my_control = false
#var object_id_counter = 0
var objects = {}

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


##
## Character syncing functions
##

func sync_death():
	pass


##
## Character ability functions
##

# adds a created object to the object dictionary and sets its name to its counter
# also sets the object as toplevel so it may move freely, not tied to character position
# because TCP sends commands in ORDER, the objects spawned by the same ability call 
# will have the same object_counter_id
func add_object(object, uuid: String) -> void:
	#var object_id_string = str(object_id_counter)
	
	#object.set_name(object_id_string)
	object.set_name(uuid)
	
	# this "unties" the object from its parent player so it may move freely
	object.set_as_toplevel(true)
	
	add_child(object)
	
	#objects[object_id_string] = object
	objects[uuid] = object
	
	#object_id_counter += 1
	

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
			#todo: server must check if player on floor as well... 
			use_ability_and_notify_server_and_start_cooldown("up", [])
		if Input.is_key_pressed(KEY_D):
			use_ability_and_notify_server_and_start_cooldown("right", [])
		if Input.is_key_pressed(KEY_A):
			use_ability_and_notify_server_and_start_cooldown("left", [])
		if Input.is_key_pressed(KEY_S):
			use_ability_and_notify_server_and_start_cooldown("down", [])
			
		# ability inputs
		
		# mouse_ability_0
		if Input.is_mouse_button_pressed(BUTTON_LEFT) && ability_usable[0]:
			use_ability_and_notify_server_and_start_cooldown("mouse_ability_0", [get_global_mouse_position()])
			
		# mouse_ability_1
		if Input.is_mouse_button_pressed(BUTTON_RIGHT) && ability_usable[1]:
			use_ability_and_notify_server_and_start_cooldown("mouse_ability_1", [get_global_mouse_position()])
			
		# key_ability_0
		if Input.is_key_pressed(KEY_E) && ability_usable[2]:
			use_ability_and_notify_server_and_start_cooldown("key_ability_0", [])
			
		# key_ability_1
		if Input.is_key_pressed(KEY_R) && ability_usable[3]:
			use_ability_and_notify_server_and_start_cooldown("key_ability_1", [])
			
		# key_ability_2
		if Input.is_key_pressed(KEY_C) && ability_usable[4]:
			use_ability_and_notify_server_and_start_cooldown("key_ability_2", [])

# 1. call the ability with arguments passed in, tba at time of button press
# 2. tell the server the command given
# 3. activate cooldown timer
# 4. attaches a uuid to this specific command (at the end of the args array) to be used for syncing purposes
func use_ability_and_notify_server_and_start_cooldown(ability_name, args):
	# converts ability name to its enumeration
	var ability_num = ability_conversions[ability_name]
	
	# checks to see if the "ability" is an actual ability or just movement	
	if (ability_num != null): # it's an ability
		# generates a uuid to track the command, adds it to args
		var ability_uuid = uuid_generator.v4()
		args.push_back(ability_uuid)
		
		# calls the ability
		callv(ability_name, args)
		
		# for debugging
		# print(str(player_id) + " activated ability: " + ability_name)
		
		# Tells server our player did the action and the arguments used
		client.send_player_rpc(player_id, ability_name, args)
		
		# Puts ability on cooldown
		ability_usable[ability_num] = false
		add_and_return_timed_effect_exit(cooldowns[ability_num], "cooldown", [ability_num])
	else: # it's a movement or other non-ability method
		call(ability_name)
		# use udp b/c movement isn't essential
		client.send_player_rpc_unreliable(player_id, ability_name, args)

# called by server to replicate the commands of another client
# 1. call the ability with arguments passed in, including the ability_uuid
# 2. activate cooldown timer
func use_ability_and_start_cooldown(ability_name: String, args) -> void:
	# converts ability name to its enumeration
	var ability_num = ability_conversions[ability_name]
	
	# checks to see if the "ability" is an actual ability or just movement	
	if (ability_num != null): # it's an ability
		# calls the ability
		callv(ability_name, args)
		
		# Puts ability on cooldown
		ability_usable[ability_num] = false
		add_and_return_timed_effect_exit(cooldowns[ability_num], "cooldown", [ability_num])
	else: # it's a movement or other non-ability method
		call(ability_name)

func cooldown(ability_num):
	ability_usable[ability_num] = true

func label_debug(text):
	get_node("Label").set_text(text)

func _physics_process(delta):
	get_node("Label").set_text(str(health as int))
	get_child(1).position = get_child(0).position

	get_input()

	# if we're hitting a surface
	if get_slide_count() > 0:
		# get one of the collisions, it's normal, and convert it into an angle
		rot_angle = get_slide_collision(get_slide_count() - 1).get_normal().angle()
	
	move_and_slide(60 * delta * (velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2)), Vector2(0.0, -1.0), false, 4, 0.9)
	
	# check here for errors: may be double-counting being on the floor b/c of outdated server info
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



# Can't use yet, need a way to check if timer exists...
#func reset_timers():
#	for effect in timed_effects:
#		effect.reset_timer()


# this function is canonically the grim reaper in the game
func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	print("I died")
	add_and_return_timed_effect_body(1, "ascend", [], 8)
	is_alive = false
	add_and_return_timed_effect_exit(20, "respawn", [])

	# clears all timedeffects

	# reset object_counter_id


func respawn():
	set_stats_default()
	is_alive = true


func ascend():
	print("ascending")
	gravity2 = -400


func up():
	# this sets the velocity instead of subtracting from it
	# which avoids the issue of "double-jumping" due to laggy info from server
	# which might cause us to believe we are on the floor even after jumping
	velocity.y = -1.5 * speed


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

func mouse_ability_0(mouse_pos, ability_uuid):
	pass

func mouse_ability_1(mouse_pos, ability_uuid):
	pass

func key_ability_0(ability_uuid):
	pass

func key_ability_1(ability_uuid):
	print("yohoho")
	pass

func key_ability_2(ability_uuid):
	pass