extends "res://ChubbyPhantom.gd"
var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")

func _ready():
	set_stats(200, 200, 200, 200)

# this is the shooty ability
#@param arg_array[0] is get_child(0).global_position, arg_array[1] is get_child(0).get_shape().get_radius() * 1.1, arg_array[2] is get_global_mouse_position().angle_to_point(get_child(0).global_position)
func ability0(arg_array):
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.fire(arg_array[0], arg_array[1], arg_array[2])
	add_child(bullet_baby)
	
	ability_usable[0] = false
	add_and_return_timed_effect(1.5, "cooldown", [0], false)