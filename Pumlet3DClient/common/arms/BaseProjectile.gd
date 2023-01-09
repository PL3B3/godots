extends KinematicBody

var base_explosion = preload("res://common/arms/BaseExplosion.tscn")

var base_damage : float = 40.0
var direct_hit_damage : float = 30.0
var falloff : float = 1.1
var speed : float = 16.0
var gravity : float = 12
var velocity := Vector3()
var fired := false
var damage_dealt = 0

signal projectile_dealt_damage(damage)

func fire(origin : Vector3, dir : Vector3, rel_vel : Vector3):
	get_global_transform().origin = origin
	velocity = dir.normalized() * speed
	fired = true

func set_collision(parent_layer, parent_mask):
	collision_layer = parent_layer
#	print("pl", parent_layer)
	collision_mask = parent_mask


func explode():
	var explosion = base_explosion.instance()
	explosion.connect("body_hit", self, "damage_body")
	explosion.connect("explosion_finished", self, "remove")
	add_child(explosion)
	explosion.setup(collision_mask, get_global_transform().origin)
	explosion.explode()
	$Shape/Mesh.visible = false
	yield(get_tree().create_timer(0.1), "timeout")
	emit_signal("projectile_dealt_damage", damage_dealt)

func damage_body(body, dist_ratio):
#	print("body hit by explosion: ", body)
	if body.has_method("hit"):
		var damage_scale = exp(-1 * falloff * dist_ratio)
		var damage = base_damage * damage_scale
		body.hit(damage)
		damage_dealt += damage
	if body.has_method("blast"):
		body.blast(get_global_transform().origin)

func remove():
	queue_free()

func _physics_process(delta):
	if fired:
		var collision = move_and_collide(velocity * delta)
		if not collision == null:
#			print(collision.collider)
			if collision.collider.has_method("hit"):
				collision.collider.hit(direct_hit_damage)
				damage_dealt += direct_hit_damage
			fired = false
			explode()
		velocity.y -= gravity * delta
