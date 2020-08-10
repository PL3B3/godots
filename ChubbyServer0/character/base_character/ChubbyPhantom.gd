extends "res://character/base_character/BaseCharacterMultiplayer.gd"
# 扭曲树

##
## Base class for multiplayer-oriented character
##


##
## Preloaded resources
##

onready var server = get_parent()

# Sync signal
signal attribute_updated(attribute_name, value)
signal method_called(method_name, args)

# for debugging
# sets global position to 0,0
func _ready():
	self.connect("attribute_updated", server, "update_attribute", [name])
	print("This is the character base class on the server side")

##
## Syncing functions top level
##

# UNRELIABLE protocol
# helper function for updating a node attribute (on clients) based on new server info
func send_updated_attribute(node_name: String, attribute_name: String, new_value) -> void:
	server.send_server_rpc_to_all_players_unreliable("set_node_attribute", [node_name, attribute_name, new_value])

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
		add_and_return_timed_effect_exit("call_and_sync", ["cooldown", [ability_num]], cooldowns[ability_num])
	else:
		# simply call the movement function
		callv(ability_name, args)

func _physics_process(delta):
	if is_alive:
		send_updates()

# updates vital player attributes on all clients
func send_updates():
	send_updated_attribute(name, "gravity2", gravity2)
	server.update_position(name, position + (server.client_delta * (velocity.rotated(rot_angle + (PI / 2)) + Vector2(0,gravity2))))
	send_updated_attribute(name, "velocity", velocity)
	send_updated_attribute(name, "rot_angle", rot_angle)
	
	#emit_signal("attribute_updated", "gravity2", gravity2)
	#emit_signal("attribute_updated", "velocity", velocity)
	#emit_signal("attribute_updated", "position", position)
	#emit_signal("attribute_updated", "rot_angle", rot_angle)

func hit(dam):
	.hit(dam)
	replicate_on_client("hit", [dam])
	emit_signal("attribute_updated", "health", health)
	if not health > 0:
		# die
		call_and_sync("die", [])
		# start respawn timer
		yield(get_tree().create_timer(5.0), "timeout")
		call_and_sync("respawn", [])
		#add_and_return_timed_effect_exit("call_and_sync", ["respawn", []], 5)
