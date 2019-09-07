extends "res://character/base_character/Character.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")

func get_input():
	.get_input()
	if Input.is_mouse_button_pressed(BUTTON_LEFT) && ability_usable[0]:
		fire_projectile()
		ability_usable[0] = false
		add_and_return_timed_effect(1.5, "cooldown", [0], false)

func fire_projectile():
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.1, get_global_mouse_position().angle_to_point(get_child(0).global_position))
	get_parent().add_child(bullet_baby)
