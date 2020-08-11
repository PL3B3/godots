extends "res://character/base_character/ChubbyPhantom.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")
var clip = 4
var big_bean_mode = true
var regen_ticks = 5

func _ready():
	health = 40
	health_cap = 40
	regen = 4
	cooldowns[0] = 0.3
	cooldowns[1] = 12

# Creates, adds, and fires bullet, returning the bullet object
func make_bullet(mouse_pos: Vector2, ability_uuid: String) -> KinematicBody2D:
	var bullet_baby = FiredProjectile.instance()
#	print("fired")
	bullet_baby.add_collision_exception_with(self)
	add_object(bullet_baby, ability_uuid)
	bullet_baby.set_as_toplevel(true)
	
	if big_bean_mode:
		bullet_baby.emit_signal("method_called", "expand", [])
	
	return bullet_baby

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String):
	# fire bullet
	var bullet = make_bullet(mouse_pos, ability_uuid)
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))
	# reduce clip
	clip -= 1
	if clip == 1:
		cooldowns[0] = 10
	if clip == 0:
		clip = 3
		cooldowns[0] = 0.3

func mouse_ability_1(mouse_pos: Vector2, ability_uuid: String):
	var bullet = make_bullet(mouse_pos, ability_uuid)
	bullet.inflict_slow = true
	bullet.time_damage_factor = 0
	bullet.speed = 600
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))

func key_ability_0(ability_uuid):
	hit(300)
