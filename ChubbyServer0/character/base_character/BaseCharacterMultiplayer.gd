extends KinematicBody2D
# 扭曲树

##
## SUPREME Base class for multiplayer-oriented character
##

var TimedEffect = preload("res://character/TimedEffect.tscn")

##
## general player stats
##

var speed: float = 90
var speed_mult: float = 1
var jump_factor = 1
var fall_factor = 0.1
var health_cap : int = 200 # defines the basic "max health" of a character, but overheal and boosts can change this
var health : int = 200
var vulnerability = 1
var vulnerability_default = 1
var regen: int = 0
var is_alive := true
var timed_effects = []

##
## for physics and visual
##

var gravity2 := 0 # downwards movement added per frame while airborne
var gravity_mult = 200
var velocity = Vector2(0,0)
var rot_angle := -(PI / 2) # used to orient movement relative to ground angle
var max_floor_angle = 0.8
var max_slide_count = 4
var friction_ratio = 0.91 # Velocity bleedoff before cliff is reached
var friction_cliff = 0.8 # Proportion of speed below which velocity falls off dramatically quickly
var friction_ratio_cliff = 0.91 # Velocity bleedoff after cliff is reached
var motion_decay_tracker = 0 # Tracks if player has recently pressed movement keys (positive) or not (negative)
var friction = false
var ticks_until_slowdown = 10 # How many physics ticks to wait before becoming still
var wall_climb_factor = 2 # The higher this is, the more a player is able to wall climb
var wall_climb_bank = 0

##
## For player mechanics
##

var death_room_position = Vector2(-2000, -2000) # where players go when dead
var respawn_position = Vector2(1500, 0)


##
## Change-tracking signals
##

signal attribute_updated(attribute_name, value)
signal method_called(method_name, args)

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
var cooldown_timers = [null, null, null, null, null]
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
var initialization_attributes = ["position", "velocity", "health", "speed_mult", "vulnerability"] # things you need to sync to copy an old player to a new client 

func _ready():
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
	speed_mult = 1
	vulnerability = vulnerability_default

func set_stats(speed, health_cap, regen, xy, player_id):
	self.speed = speed
	self.health_cap = health_cap
	self.health = health_cap
	self.regen = regen
	self.player_id = player_id
	set_global_position(xy)

# Array, not dictionary, optimizing for network usage
func get_initialization_values():
	var initialization_values = {}
	for attrib in initialization_attributes:
		initialization_values[attrib] = get(attrib)
	return initialization_values

func set_initialization_values(initialization_values):
	if initialization_values.size() == initialization_attributes.size():
		for attrib in initialization_values:
			set(attrib, initialization_values[attrib])
	else:
		print("Given " + str(initialization_values.size()) + " values, but expected " + str(initialization_attributes.size()))

# there are 6 teams, numbered 0-5, corresponding to the first six layer/mask bits
func set_team(team_num: int):
	if team_num < 0:
		team_num = 0
	elif team_num > 5:
		team_num = 5
	
	team = team_num
	
	# Set collision layer to team_num only
	for l in range(0,6):
		set_collision_layer_bit(l, l == team_num)
	
	# Set mask to include all but our team
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
		# Movement done here
		move_and_slide(velocity.rotated(rot_angle + (PI / 2)), Vector2(0.0, -1.0), true, max_slide_count, max_floor_angle)

		if friction:
			velocity.x *= friction_ratio
		
		# gravity
		if is_on_ceiling():
			velocity.y = 0
		
		
		if is_on_floor():
			wall_climb_bank = 90
			velocity.y = speed * speed_mult * 0.08
			rot_angle = get_floor_normal().angle()
		else:
			#rot_angle += 0.1 * ((-PI / 2) - rot_angle)
			if velocity.y < 1.5 * gravity_mult:
				velocity.y += gravity_mult * delta
			
			# ease rot_angle towards - PI / 2
			# These angles interpolate normally b/c there's no "angle jump"
			if rot_angle < PI / 2 and rot_angle > -PI:
				rot_angle += 0.04 * ((- PI / 2) - rot_angle)
			# These angles are weird and need to jump between PI and -PI, which represent the same angle
			else:
				rot_angle += 0.04 * ((3 * PI / 2) - rot_angle)
				if rot_angle > PI:
					rot_angle -= 2 * PI
		
		if is_on_wall():
			if wall_climb_bank > 0:
				#print(velocity.y)
				if is_on_floor():
					velocity.y = 0
				velocity.y -= (abs(velocity.x) / (speed * speed_mult)) * (velocity.y + (gravity_mult * speed_mult)) * wall_climb_factor * delta
				#print(velocity.y)
				wall_climb_bank -= 1
			#velocity.y -= gravity_mult * 0.8 * delta
			#if velocity.y > 0.5 * gravity_mult:
			#	velocity.y += 0.02 * ((0.5 * gravity_mult) - velocity.y)
			#move_and_slide(Vector2(0, -(abs(velocity.x) / (speed * speed_mult)) * wall_climb_factor * gravity_mult), Vector2(0.0, -1.0), true, max_slide_count, max_floor_angle)



func put_label(text):
	get_node("Label").set_text(text)

func sayhi():
	print("hi")
	
# ESSENTIAL
func cooldown(ability_num):
	ability_usable[ability_num] = true

# ESSENTIAL
func hit(dam):
	health -= dam * vulnerability as int

func die():
	is_alive = false
	# Only in Jesus mode
	#add_and_return_timed_effect_body("ascend", [], 4)
	# no movement
	velocity = Vector2()
	# disable collisions
	$CollisionShape2D.set_deferred("disabled", true)
	position = death_room_position
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
	velocity.y = -1 * jump_factor * gravity_mult * speed_mult
	#velocity.y = -1.4 * gravity_mult * speed_mult

func down():
	if velocity.y < 2 * gravity_mult * speed_mult:
		velocity.y += fall_factor * gravity_mult * speed_mult
	
	#fall through oneways
	#var map_tiles = get_node("/root/ChubbyServer").current_map.get_node("TileMap")
	#var cell_below_id = map_tiles.get_cellv(map_tiles.world_to_map(position + Vector2(0, 30)))
	#print(cell_below_id)
	#if map_tiles.tile_set.tile_get_shape_one_way(cell_below_id, cell_below_id):
	if is_on_floor():
		position += Vector2(0, 1)



func right():
	motion_decay_tracker = ticks_until_slowdown
	friction = false
	if velocity.x < speed * speed_mult:
		velocity.x += 0.15 * speed * speed_mult


func left():
	motion_decay_tracker = ticks_until_slowdown
	friction = false
	if velocity.x > -speed * speed_mult:
		velocity.x -= 0.15 * speed * speed_mult


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
