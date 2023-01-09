extends "res://common/arms/BaseWeapon.gd"

var projectile = preload("res://common/arms/BaseProjectile.tscn")

func init():
	fire_rate_default = 0.6
	reload_time_default = 1.2
	clip_size_default = 4
	clip_remaining = clip_size_default
	ammo_default = 200
	ammo_remaining = ammo_default

func primary_fire(fire_transform: Transform, fire_parameters):
	fire_projectile(fire_transform, fire_parameters, 30.0, 40.0)

func secondary_fire(fire_transform: Transform, fire_parameters):
	fire_projectile(fire_transform, fire_parameters, 0.0, 130.0)

func tertiary_fire(fire_transform: Transform, fire_parameters):
	fire_projectile(fire_transform, fire_parameters, 70.0, -70.0)

func fire_projectile(fire_transform: Transform, fire_parameters, explosive_dmg, direct_dmg):
	var projectile_to_fire = projectile.instance()
	projectile_to_fire.set_as_toplevel(true)
	projectile_to_fire.connect("projectile_dealt_damage", self, "notify_dealt_damage")
#	print("wielder mask ", wielder.collision_mask)
	projectile_to_fire.set_collision(wielder.collision_layer, wielder.collision_mask)
	projectile_to_fire.base_damage = explosive_dmg
	projectile_to_fire.direct_hit_damage = direct_dmg
	for object in ignored_objects:
		projectile_to_fire.add_collision_exception_with(object)
	add_child(projectile_to_fire)
	projectile_to_fire.fire(
		fire_transform.origin,
		-1 * fire_transform.basis.z,
		fire_parameters[1])

func notify_dealt_damage(damage):
	emit_signal("dealt_damage", damage)
