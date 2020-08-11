extends "res://character/base_character/ChubbyCharacter.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")


func _ready():
	health = 40
	health_cap = 40
	cooldowns[0] = 2
	cooldowns[1] = 10

# Creates, adds, and fires bullet, returning the bullet object
func make_bullet(mouse_pos: Vector2, ability_uuid: String) -> KinematicBody2D:
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.add_collision_exception_with(self)
	add_object(bullet_baby, ability_uuid)
	bullet_baby.set_as_toplevel(true)
	return bullet_baby

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String):
	var bullet = make_bullet(mouse_pos, ability_uuid)
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))

func mouse_ability_1(mouse_pos: Vector2, ability_uuid: String):
	var bullet = make_bullet(mouse_pos, ability_uuid)
	bullet.inflict_slow = true
	bullet.time_damage_factor = 0
	bullet.speed = 600
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))
	
# this hits us for 40 damage on serverside
