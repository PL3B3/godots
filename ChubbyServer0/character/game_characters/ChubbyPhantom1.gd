extends "res://character/base_character/ChubbyPhantom.gd"

var health_max = 240
var mouse_pos_current := Vector2()
var hit_scanning := false
var link_target : KinematicBody2D = null

func _ready():
	health = 20
	health_cap = 20

func _per_second():
	# Exponentially grow health up to cap
	# It takes approx 78 seconds to get to max hp w/ only regen
	if is_alive and health < health_max:
		emit_signal("attribute_updated", "health", clamp(1 + health * 1.025, 0, health_max) as int)
		if link_target != null and link_target.has_method("cooldown"):
			link_target.add_and_return_timed_effect_body("emit_signal", ["method_called", "hit", [2]], 12)
			add_and_return_timed_effect_body("emit_signal", ["method_called", "hit", [-2]], 12)

func _physics_process(delta):
	if hit_scanning:
		var space_state = get_world_2d().direct_space_state
		# Only checks players b/c walls don't matter to sponge
		link_target = space_state.intersect_ray(position, mouse_pos_current, [self], 63).collider
		hit_scanning = false

func reset_ability_and_cooldown(ability_num: int):
	cooldown_timers[ability_num].start(0.01)

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String):
	mouse_pos_current = mouse_pos
	hit_scanning = true

func key_ability_0(ability_uuid: String):
	# Check if link target is player
	if link_target != null and link_target.has_method("cooldown"):
		pass
