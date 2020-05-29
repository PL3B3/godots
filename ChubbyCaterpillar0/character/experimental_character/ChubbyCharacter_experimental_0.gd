extends "res://character/base_character/ChubbyCharacter.gd"

func _ready():
	cooldowns = [10, 10, 10, 10, 10, 10]
	pass
	
func key_ability_0():
	print("Ability used")
	get_child(1).size *= 1.5