extends KinematicBody2D
# 扭曲树

##
## SUPREME Base class for multiplayer-oriented character
##

var TimedEffect = preload("res://character/TimedEffect.tscn")

##
## general player stats
##

var speed: float = 350
var health_cap : int = 200 # defines the basic "max health" of a character, but overheal and boosts can change this
var health : int = 200
var regen: int = 0
var is_alive := true
var timed_effects = []

##
## for physics and visual
##

var gravity2 := 0 # downwards movement added per frame while airborne
var gravity_mult = 300
var velocity = Vector2(0,0)
var rot_angle := -(PI / 2) # used to orient movement relative to ground angle
var max_floor_angle = 0.9
var max_slide_count = 4
var friction_ratio = 0.9 # Velocity bleedoff before cliff is reached
var friction_cliff = 0.8 # Proportion of speed below which velocity falls off dramatically quickly
var friction_ratio_cliff = 0.91 # Velocity bleedoff after cliff is reached
var motion_decay_tracker = 0 # Tracks if player has recently pressed movement keys (positive) or not (negative)
var ticks_until_slowdown = 10 # How many physics ticks to wait before becoming still

##
## For player mechanics
##

var death_room_position = Vector2(0, 500) # where players go when dead
var respawn_position = Vector2(1500, 0)

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
var cooldowns = [1, 1, 1, 1, 1]
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

var player_id : int # unique network id of the player
var type := "base"
var team : int
var team_colors = [Color(0,0.7,1), Color(1,1,0.1), Color(1,0.1,0.3), Color(0.9,0.2,0.6), Color(0.8,0.5,0.5), Color(0.3,0.2,0.5)]
#var object_id_counter = 0
var objects = {}

func _ready():
	position = Vector2(1000, 0)
	# sets masks to check fauna, pickups, and environment
	for b in range(6, 9):
		set_collision_mask_bit(b, true)

##
## For modifying character stats 
##
func set_id(id):
	self.player_id = id

func set_stats_default():
	health = health_cap

func set_stats(speed, health_cap, regen, xy, player_id):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health_cap
	self.regen = regen
	self.player_id = player_id
	set_global_position(xy)

# there are 6 teams, numbered 0-5, corresponding to the first six layer/mask bits
func set_team(team_num: int):
	if team_num < 0:
		team_num = 0
	elif team_num > 5:
		team_num = 5
	
	set_collision_layer_bit(team_num, true)
	
	for t in range(0,6):
		set_collision_mask_bit(t, t != team_num)
	
	$Sprite.modulate = team_colors[team_num]

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

# function to remove an object
func remove_object(uuid: String) -> void:
	var object_to_remove = get_node(uuid)

	# check if object exists
	if is_instance_valid(object_to_remove):
		objects[uuid].queue_free()
		objects.erase(uuid)
	else:
		print("Object " + str(uuid) + " is not available for removal")

func add_and_return_timed_effect_full(enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats):
	var timed_effect = TimedEffect.instance()
	add_child(timed_effect)
	timed_effect.init_timer(enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats)
	timed_effects.push_back(timed_effect)
	
func add_and_return_timed_effect_exit(exit_func, exit_args, repeats):
	add_and_return_timed_effect_full("", [], "", [], exit_func, exit_args, repeats)

func add_and_return_timed_effect_body(body_func, body_args, repeats):
	add_and_return_timed_effect_full("", [], body_func, body_args, "", [], repeats)

# calculates and syncs position/movement
func _physics_process(delta):
	if is_alive:
		put_label(str(health as int))
		get_child(1).position = get_child(0).position
		
		if get_slide_count() > 0:
			# ensures rot_angle is - PI / 2 if we're only touching a ceiling
			var rot_angle_cume = Vector2()
			var only_touching_ceiling = true
			for i in range(0,get_slide_count()):
				var slide_normal = get_slide_collision(i).get_normal() 
				var slide_angle = slide_normal.angle()
				# If angle isn't a ceiling normal
				if slide_angle >= (PI / 2) + max_floor_angle or slide_angle <= (PI / 2) - max_floor_angle:
					rot_angle_cume += slide_normal
					only_touching_ceiling = false
				else:
					velocity.y = 0
					if gravity2 < 0.1 * gravity_mult:
						gravity2 = 0.1 * gravity_mult
			if only_touching_ceiling:
				rot_angle = - PI / 2
			else:
				rot_angle = rot_angle_cume.angle()
		
		# Movement done here
		move_and_slide(velocity.rotated(rot_angle + (PI / 2)) + Vector2(0,gravity2), Vector2(0.0, -1.0), true, max_slide_count, max_floor_angle)
		
		# Decrement left and right decay counters. If they reach zero or less, friction should be activated. Otherwise, friction should be turned off
		motion_decay_tracker -= 1
		if motion_decay_tracker < 0:
			velocity.x *= friction_ratio
		
		# Friction
		if is_on_floor():
			gravity2 = 10
		else:
			rot_angle = -PI / 2
			if gravity2 < 4 * speed:
				gravity2 += gravity_mult * delta

func put_label(text):
	get_node("Label").set_text(text)

func sayhi():
	print("hi")
	
# ESSENTIAL
func cooldown(ability_num):
	ability_usable[ability_num] = true

# ESSENTIAL
func hit(dam):
	health -= dam as int

func die():
	is_alive = false
	# Only in Jesus mode
	#add_and_return_timed_effect_body("ascend", [], 4)
	# no movement
	velocity = Vector2()
	# disable collisions
	$CollisionShape2D.set_deferred("disabled", true)
	# make invisible
	$Sprite.visible = false
	timed_effects = []
	# move far away
	print("I died")

func respawn():
	print("respawning")
	set_stats_default()
	$CollisionShape2D.set_deferred("disabled", false)
	$Sprite.visible = true
	position = respawn_position
	ability_usable = [true, true, true, true, true]
	is_alive = true

func ascend():
	print("ascending")


func up():
	gravity2 = -gravity_mult

func down():
	pass
#   velocity.y = 2 * speed


func right():
	motion_decay_tracker = ticks_until_slowdown
	if velocity.x < speed:
		velocity.x += 0.15 * speed


func left():
	motion_decay_tracker = ticks_until_slowdown
	if velocity.x > -speed:
		velocity.x -= 0.15 * speed


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
