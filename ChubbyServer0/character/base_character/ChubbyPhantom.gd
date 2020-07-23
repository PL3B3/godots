extends "res://character/base_character/BaseCharacterMultiplayer.gd"
# 扭曲树

##
## Base class for multiplayer-oriented character
##


##
## Preloaded resources
##

onready var server = get_parent()

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

# call a method on this phantom's client instance
func replicate_on_client(method_name: String, args) -> void:
	server.send_server_rpc_to_all_players("call_player_method", [player_id, method_name, args])

# calls a method on this phantom and all its client instances
func call_and_sync(method_name: String, args) -> void: 
	callv(method_name, args)
	replicate_on_client(method_name, args)


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

func _physics_process(delta):
	send_updates()

# updates vital player attributes on all clients
func send_updates():
	send_updated_attribute(str(player_id), "gravity2", gravity2)
	send_updated_attribute(str(player_id), "velocity", velocity)
	send_updated_attribute(str(player_id), "position", position)
	send_updated_attribute(str(player_id), "rot_angle", rot_angle)

func die():
       # performs death functionality
       .die()
       # tells client to die
       replicate_on_client("die", [])
       # starts respawn timer
       add_and_return_timed_effect_exit("call_and_sync", ["respawn", []], 10)

func respawn():
       # performs respawn functionality
       .respawn()
       # tell client to respawn
       replicate_on_client("respawn", [])