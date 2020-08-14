extends "res://character/base_character/ChubbyPhantom.gd"

var FiredProjectile = preload("res://game_objects/fired_projectiles/FiredProjectile.tscn")
var EffectBullet = preload("res://game_objects/fired_projectiles/EffectBullet.tscn")
var explosion_radius = 400
var explosion_max_damage = 31
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
	cooldowns[4] = 60

func _per_second():
	if health < 60 and regen_ticks > 0:
		emit_signal("method_called", "hit", [-1 * regen])
	regen_ticks -= 1

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
	# fire bullet
	var bullet = make_bullet(mouse_pos, ability_uuid, FiredProjectile.instance())
	bullet.fire(get_child(0).global_position, get_child(0).get_shape().get_radius() * 1.3, mouse_pos.angle_to_point(get_child(0).global_position))
	# reduce clip
	clip -= 1
	if clip == 1:
		cooldowns[0] = 8
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
	# Make all abilities unusable for 5 (more) seconds
	for i in range(0,cooldowns.size()):
		ability_usable = [false, false, false, false, false]
		cooldown_timers[i].start(cooldown_timers[i].get_time_left() + 5)
	# Give 5 ticks of regen...total 20 health
	regen_ticks = 5

func key_ability_1(ability_uuid: String):
	emit_signal("attribute_updated", "big_bean_mode", true)
	add_and_return_timed_effect_exit("emit_signal", ["attribute_updated", "big_bean_mode", false], 8)
	#emit_signal("method_called", "add_and_return_timed_effect_exit", ["set", ["big_bean_mode", false], 8])
	#emit_signal("method_called", "add_and_return_timed_effect_exit", ["emit_signal", ["attribute_updated", "big_bean_mode", false], 8])

func key_ability_2(ability_uuid: String):
	print("BOOM!")
	# This explosion need not be synced with client because it is nearly instantaneous
	for player in server.players.values():
		# If player is enemy
		if player.team != team:
			var distance = clamp(position.distance_to(player.position) - \
				(player.get_node("CollisionShape2D").get_shape().get_radius() + $CollisionShape2D.get_shape().get_radius()), 0, explosion_radius)
			if distance < explosion_radius:
				player.emit_signal("method_called", "hit", [explosion_max_damage * pow(1 - (distance / explosion_radius), 2)])
	emit_signal("method_called", "hit", [30])
