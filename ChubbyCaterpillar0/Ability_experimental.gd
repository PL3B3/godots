extends "res://character/base_character/Ability.gd"

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	init_ability(KEY_E, "Expand", true)

func use_ability(args):
	print("Ability used")
	parent.get_child(1).size *= 1.5