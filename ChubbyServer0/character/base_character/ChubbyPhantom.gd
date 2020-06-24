extends KinematicBody2D
# 扭曲树

##
## Base class for multiplayer-oriented character
##


##
## Preloaded resources
##

var TimedEffect = preload("res://character/TimedEffect.tscn")
onready var server = get_parent()

##
## general player stats
##

# float: speed is the character's movement speed
# float: health_cap defines the basic "max health" of a character, but overheal and boosts can change this
# float: health is actual current health
# float: regen is the amount of health to be added or removed per second from the character
# char: team is a letter representation of which team you are on
var speed = 200
var health_cap : int = 200
var health : int = 200
var regen = 0
var team = 'a'
var is_alive = true
var timed_effects = []

##
## for physics and visual
##

# float: gravity2 is a workaround to physics simulation problems (I don't want to code a whole-ass momentum thing yet)
# 	It starts at 9.8 as a default 
# Vector2: velocity tracks player movement
# float: rot_angle is used to orient the player perpendicular to collision normal
var gravity2 = 0
var velocity = Vector2(0,0)
var rot_angle = -(PI / 2)
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
# decimal: object_id_counter is # Incremented every time child object is spawned
# 	Each child object is named [player_id]-[this number]
# 	Example: player id is 3000123, this counter is 5, 
# 	then the object is: "3000123-5" as a STRING
var player_id
var type = "base"
var character_under_my_control = false
#var object_id_counter = 0
var objects = {}
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

##
## Syncing functions top level
##

# UNRELIABLE protocol
# helper function for updating a node attribute (on clients) based on new server info
func send_updated_attribute(node_name: String, attribute_name: String, new_value) -> void:
	server.send_server_rpc_to_all_players_unreliable("update_node_attribute", [node_name, attribute_name, new_value])


# calls a method on this phantom and all its client instances
func call_and_sync(method_name: String, args) -> void: 
	callv(method_name, args)
	server.send_server_rpc_to_all_players("call_player_method", [method_name, args])


##
## Character ability functions
##

# adds a created object to the object dictionary and sets its name to its counter
# also sets the object as toplevel so it may move freely, not tied to character position
# because TCP sends commands in ORDER, the objects spawned by the same ability call 
# will have the same object_counter_id
func add_object(object, uuid):
	#var object_id_string = str(object_id_counter)
	
	#object.set_name(object_id_string)
	object.set_name(uuid)
	
	# this "unties" the object from its parent player so it may move freely
	object.set_as_toplevel(true)
	
	add_child(object)
	
	#objects[object_id_string] = object
	objects[uuid] = object
	
	#object_id_counter += 1


# removes object
func remove_object(uuid: String) -> void:
	objects[uuid].queue_free()
	objects.erase(uuid)
#	server.send_server_rpc_to_all_players("remove_player_object", [player_id, uuid])


func add_and_return_timed_effect_full(enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effect.init_timer(enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats)
	timed_effects.push_back(timed_effect)


func add_and_return_timed_effect_exit(exit_func, exit_args, repeats):
	add_and_return_timed_effect_full("", [], "", [], exit_func, exit_args, repeats)

func add_and_return_timed_effect_body(body_func, body_args, repeats):
	add_and_return_timed_effect_full("", [], body_func, body_args, "", [], repeats)

# 1. call the ability with arguments passed in, tba at time of button press
# 2. activate cooldown timer
func use_ability_and_start_cooldown(ability_name, args):
	# converts ability name to its arbitrary number from 0-4, or null if...
	# ...the ability is just a movement
	var ability_num = ability_conversions.get(ability_name)
	
	# if the ability is an actual ability and not just movement
	if (ability_num != null):
		# call the ability
		callv(ability_name, args)
		# Puts ability on cooldown
		ability_usable[ability_num] = false
		add_and_return_timed_effect_exit("call_and_sync", ["cooldown", [ability_num]], cooldowns[ability_num])
	else:
		# simply call the movement function
		callv(ability_name, args)


func label_debug(text):
	get_node("Label").set_text(text)

# calculates and syncs position/movement
func _physics_process(delta):
	get_node("Label").set_text(str(health as int))
	get_child(1).position = get_child(0).position

	if (physics_processing):
		if get_slide_count() > 0:
			# get one of the collisions, it's normal, and convert it into an angle
			rot_angle = get_slide_collision(get_slide_count() - 1).get_normal().angle()

		move_and_slide(60 * delta * (velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2)), Vector2(0.0, -1.0), false, 4, 0.9)
		
		send_updated_attribute(str(player_id), "velocity", velocity)
		send_updated_attribute(str(player_id), "gravity2", gravity2)
		
		if is_on_floor():
			velocity = Vector2()
			gravity2 = 0
		else:
			gravity2 += 9.8

		send_updated_attribute(str(player_id), "position", position)
		send_updated_attribute(str(player_id), "rot_angle", rot_angle)


# ESSENTIAL
func cooldown(ability_num):
	ability_usable[ability_num] = true


# ESSENTIAL
func hit(dam):
	health -= dam as int
	send_updated_attribute(str(player_id), "health", health)
	print("Was hit")
	if not health > 0:
		die()


func sayhi():
	print("hi")


# Can't use yet, need a way to check if timer exists...
#func reset_timers():
#	for effect in timed_effects:
#		effect.reset_timer()


func die():
	# I should expand this function to incorporate respawns, etc.. Don't want to have to reload resources every time
	print("I died")
	add_and_return_timed_effect_body("ascend", [], 4)
	is_alive = false
	add_and_return_timed_effect_exit("respawn", [], 5)
	# queue_free()


func respawn():
	set_stats_default()
	is_alive = true


func ascend():
	print("ascending")
	gravity2 = -400


func up():
	velocity.y = -1.5 * speed


func down():
	velocity.y += 0.1 * speed


func right():
	#print("right called on chubbyphantom for player:" + str(player_id))
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
	print("key_ability_0 activated on player: " + str(player_id))
	pass

func key_ability_1(ability_uuid):
	print("yohoho")
	pass

func key_ability_2(ability_uuid):
	pass