extends "res://character/base_character/BaseCharacterMultiplayer.gd"
# 扭曲树

##
## Base class for multiplayer-oriented character
##


##
## Preloaded resources
##

onready var server = get_parent()

##
## These are the attributes/methods shared between players that are linked to the squeegee
##
var attributes_to_replicate = ["speed_mult", "vulnerability"]
var methods_to_replicate = ["hit", "die", "add_and_return_timed_effect_exit", "add_and_return_timed_effect_body", "add_and_return_timed_effect_full"]

# Dictionary of clients who we should transmit our updates to
# int (id), bool: yes or no sync
var clients_to_sync_with = {}

# for debugging
# sets global position to 0,0
func _ready():
	self.connect("attribute_updated", server, "set_node_attribute_universal", [name])
	self.connect("method_called", server, "call_node_method_universal", [name])
	print("This is the character base class on the server side")
	for i in range(0, cooldowns.size()):
		var timer = Timer.new()
		timer.set_one_shot(true)
		timer.connect("timeout", self, "emit_signal", ["method_called", "cooldown", [i]])
		add_child(timer)
		cooldown_timers[i] = timer
	var ps_timer = Timer.new()
	ps_timer.set_one_shot(false)
	add_child(ps_timer)
	ps_timer.start(1)
	ps_timer.connect("timeout", self, "_per_second")
	ps_timer.set_name("per_second_timer")
	

func _per_second():
	#print(health as int)
	pass

##
## Syncing functions top level
##

# UNRELIABLE protocol
# helper function for updating a node attribute (on clients) based on new server info
func send_updated_attribute(node_name: String, attribute_name: String) -> void:
	server.send_server_rpc_to_all_players_unreliable("update_node_attribute", [node_name, attribute_name, get(attribute_name)])

# Reliably send updated attribs
func set_self_attribute_on_client(attribute_name: String) -> void:
	server.set_node_attribute_on_clients(attribute_name, get(attribute_name), name)

# call a method on all this phantom's client instances
func replicate_on_client(method_name: String, args) -> void:
	server.send_server_rpc_to_all_players("call_node_method", [name, method_name, args])

# calls a method on this phantom and all its client instances
func call_and_sync(method_name: String, args) -> void:
	callv(method_name, args)
	replicate_on_client(method_name, args)


# 1. call the ability with arguments passed in, tba at time of button press
# 2. activate cooldown timer
func use_ability_and_start_cooldown(ability_name, args):
	if not is_alive:
		return
	# converts ability name to its arbitrary number from 0-4, or null if...
	# ...the ability is just a movement
	var ability_num = ability_conversions.get(ability_name)
	
	# if the ability is an actual ability and not just movement
	if (ability_num != null):
		# call the ability
		callv(ability_name, args)
		# Puts ability on cooldown
		ability_usable[ability_num] = false
		#add_and_return_timed_effect_exit("call_and_sync", ["cooldown", [ability_num]], cooldowns[ability_num])
		#add_and_return_timed_effect_exit("emit_signal", ["method_called", "cooldown", [ability_num]], cooldowns[ability_num])
		#yield(get_tree().create_timer(cooldowns[ability_num]), "timeout")
		#emit_signal("method_called", "cooldown", [ability_num])
		cooldown_timers[ability_num].start(cooldowns[ability_num])
	else:
		# simply call the movement function
		callv(ability_name, args)

var already_notified_friction_off = false
func _physics_process(delta):
	if is_alive:
		motion_decay_tracker -= 1
		if motion_decay_tracker < 0:
			friction = true
		send_updates()

var counter : int = 0
var last_position : Vector2
var last_gravity2 : float
var last_velocity : Vector2
var last_rot_angle : float
var last_friction : bool
var position_update_delta_limit = 1
var gravity2_update_delta_limit = 1
var velocity_update_delta_limit = 3
var rot_angle_update_delta_limit = 0.01
# updates vital player attributes on all clients
func send_updates():
	# 30 times a second
	if counter % 3 == 0:
		#send_updated_attribute(name, "gravity2", gravity2)
		send_updated_attribute(name, "velocity")
		send_updated_attribute(name, "rot_angle")
		if position.distance_to(last_position) > position_update_delta_limit:
			server.update_player_position(player_id, position + (server.client_delta * (velocity.rotated(rot_angle + (PI / 2)))))
		if friction != last_friction:
			send_updated_attribute(name, "friction")
	# 6 times a second
#	if counter % 15 == 0:
		# sync gravity, rot angle, and velocity to client if they've changed substantially in the last 6th of a second
#		if abs(gravity2 - last_gravity2) > gravity2_update_delta_limit:
			#print("grav2 changed from: " + str(last_gravity2) + " to " + str(gravity2))
#			send_updated_attribute(name, "gravity2")
#		if velocity.distance_to(last_velocity) > velocity_update_delta_limit:
			#print("velocity changed from: " + str(last_velocity) + " to " + str(velocity))
#			send_updated_attribute(name, "velocity")
#		if abs(rot_angle - last_rot_angle) > rot_angle_update_delta_limit and abs(rot_angle - last_rot_angle) < (2 * PI - rot_angle_update_delta_limit):
			#print("rot_angle changed from: " + str(last_rot_angle) + " to " + str(rot_angle))
#			send_updated_attribute(name, "rot_angle")
		
		# update attribute trackers
		last_position = position
		last_gravity2 = gravity2
		last_velocity = velocity
		last_rot_angle = rot_angle
		last_friction = friction
		
		
		counter = 0
	#emit_signal("attribute_updated", "gravity2", gravity2)
	#emit_signal("attribute_updated", "velocity", velocity)
	#emit_signal("attribute_updated", "position", position)
	#emit_signal("attribute_updated", "rot_angle", rot_angle)
	counter += 1


# used when a player (re)connects to make sure every client has their correct position
func full_sync():
	var attributes_to_sync = ["position", "velocity", "health", "speed_mult", "vulnerability"]
	for attribute_name in attributes_to_sync:
		set_self_attribute_on_client(attribute_name)

func hit(dam):
	print("hit called")
	.hit(dam)
	#emit_signal("attribute_updated", "health", health - (dam as int))
	if not health > 0:
		# die
		emit_signal("method_called", "die", [])
		# start respawn timer
		yield(get_tree().create_timer(5.0), "timeout")
		emit_signal("method_called", "respawn", [])

##
## Used to replicate some effects between squeegees and their link targets
##
func replicate_attribute_updated(attribute_name: String, new_value, node_name: String):
	if attributes_to_replicate.has(attribute_name):
		server.set_node_attribute_universal(attribute_name, new_value, node_name)

func replicate_method_called(method_name: String, args, node_name: String):
	if methods_to_replicate.has(method_name):
		server.call_node_method_universal(method_name, args, node_name)
