extends "res://character/base_character/ChubbyPhantom.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")

func _ready():
	cooldowns[0] = 2
	cooldowns[1] = 10

func mouse_ability_0(mouse_pos, ability_uuid):
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.add_collision_exception_with(self)
	add_object(bullet_baby, ability_uuid)
	bullet_baby.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))
	bullet_baby.set_as_toplevel(true)

func mouse_ability_1(mouse_pos, ability_uuid):
	pass

func key_ability_0(ability_uuid):
	hit(300)
