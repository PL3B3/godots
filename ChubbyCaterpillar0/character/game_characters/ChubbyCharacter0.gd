extends "res://character/base_character/ChubbyCharacter.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String) -> void:
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.add_collision_exception_with(self)
	add_object(bullet_baby, ability_uuid)
	bullet_baby.fire(get_child(1).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))

func mouse_ability_1(mouse_pos: Vector2, ability_uuid: String) -> void:
    var ray_cast = RayCast2D.new()
    add_child(ray_cast)
	
func key_ability_0(ability_uuid):
	print("%s, %s" % [get_child(0).global_position, get_child(1).global_position])