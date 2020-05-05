extends Node

# Class represents an ability or action a character can take

# Key/click under project settings inputmap which is bound to this ability
var bind = null
var ability_name
var reliable

# parent node is the character with this ability
onready var parent = get_parent()

func init_ability(bind, ability_name, reliable):
	self.bind = bind
	self.ability_name = ability_name
	self.reliable = reliable

func trigger():
	if Input.is_action_pressed(bind):
		# Get necessary argument array, will equal [] by default
		var args = query_args()

		# for debugging
		print(parent.player_id + " activated ability: " + ability_name)

		# Tells server our player did the action
		get_node("/root/ChubbyServer").send_player_rpc(parent.player_id, ability_name, args)

		# call ability with args
		use_ability(args)

		# Puts ability on cooldown
		parent.ability_usable[ability_name] = false
		parent.callv("add_and_return_timed_effect_exit", 10, "cooldown", [0])

# Main body of the ability function - to be overridden
func use_ability(args):
	pass

# Function which gets arguments the ability may need
func query_args():
	return []