extends "res://character/base_character/ChubbyCharacter.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")
var EffectBullet = preload("res://game_objects/fired_projectiles/EffectBullet.tscn")
var clip = 4
var big_bean_mode = false
var regen_ticks = 0

func _ready():
	health = 40
	health_cap = 40
	regen = 4
	cooldowns[0] = 0.3
	cooldowns[1] = 12
	cooldowns[2] = 26
	cooldowns[3] = 16

# Creates, adds, and fires bullet, returning the bullet object
func make_bullet(mouse_pos: Vector2, ability_uuid: String, bullet_baby: KinematicBody2D) -> KinematicBody2D:
#	print("fired")
	bullet_baby.add_collision_exception_with(self)
	add_object(bullet_baby, ability_uuid)
	bullet_baby.set_as_toplevel(true)
	
	if big_bean_mode:
		bullet_baby.expand()
	
	return bullet_baby

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String):
	var bullet = make_bullet(mouse_pos, ability_uuid, FiredProjectile.instance())
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))
	# reduce clip
	clip -= 1
	if clip == 1:
		cooldowns[0] = 10
	if clip == 0:
		clip = 3
		cooldowns[0] = 0.3

func mouse_ability_1(mouse_pos: Vector2, ability_uuid: String):
	var bullet = make_bullet(mouse_pos, ability_uuid, EffectBullet.instance())
	bullet.inflict_slow = true
	bullet.time_damage_factor = 0
	bullet.speed = 600
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))

func key_ability_0(ability_uuid: String):
	# pre-emptively makes abilities unusable (in case server sync doesn't come through in time)
	ability_usable = [false, false, false, false, false]
