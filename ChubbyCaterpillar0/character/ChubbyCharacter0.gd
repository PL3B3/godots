extends "res://character/base_character/ChubbyCharacter.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")

func ability0():
	.ability0()
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.1, get_global_mouse_position().angle_to_point(get_child(0).global_position))
	get_parent().add_child(bullet_baby)
