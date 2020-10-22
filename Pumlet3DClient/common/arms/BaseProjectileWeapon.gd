extends "res://common/arms/BaseWeapon.gd"

var projectile = preload("res://common/arms/BaseProjectile.tscn")

func init():
	fire_rate_default = 1
	reload_time_default = 2.5
	clip_size_default = 4
	clip_remaining = clip_size_default
	ammo_default = 16
	ammo_remaining = ammo_default

func primary_fire(fire_transform: Transform, fire_parameters):
	var projectile_to_fire = projectile.instance()
	projectile_to_fire.set_as_toplevel(true)
	projectile_to_fire.connect("projectile_dealt_damage", self, "notify_dealt_damage")
	projectile_to_fire.set_collision(wielder.collision_layer, wielder.collision_mask)
	for object in ignored_objects:
		projectile_to_fire.add_collision_exception_with(object)
	add_child(projectile_to_fire)
	projectile_to_fire.fire(
		fire_transform.origin,
		-1 * fire_transform.basis.z,
		fire_parameters[1])

func secondary_fire(fire_transform: Transform, fire_parameters):
	print("Fired weapon in secondary mode")

func tertiary_fire(fire_transform: Transform, fire_parameters):
	print("Fired weapon in tertiary mode")

func notify_dealt_damage(damage):
	emit_signal("dealt_damage", damage)
