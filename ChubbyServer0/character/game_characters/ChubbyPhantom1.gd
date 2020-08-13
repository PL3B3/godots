extends "res://character/base_character/ChubbyPhantom.gd"

var health_max : int = 120
var health_to_add : float = 0
var mouse_pos_current := Vector2()
var hit_scanning := false
#var link_target : KinematicBody2D = null
var link_targets = {} # keys are string ID's of targeted players, values are how many seconds of blood we can draw
var most_recent_link_target : String # name of latest targetted player
var effect_share_link_target : String
var absorbing_health = false
var giving_health = false

func _ready():
	health = 20
	health_cap = 20
	cooldowns[0] = 4
	cooldowns[2] = 0.5
	cooldowns[3] = 0.5

func _per_second():
	# Exponentially grow health up to cap
	# It takes 100 seconds to get from 20 to 120 with only regen
	if is_alive and health <= health_max:
		# Depending on how much health you have, add to a cumulative regen tracker
		if health >= 100:
			health_to_add += 2
		elif health >= 70:
			health_to_add += 1.5
		elif health >= 40:
			health_to_add += 1
		elif health >= 20:
			health_to_add += 0.5
		else:
			health_to_add += 0.2
		#print(health_to_add)
		# Add the regen tracker (rounded down to int) as health
		emit_signal("attribute_updated", "health", clamp(health + (health_to_add as int), 0, health_max) as int)
		# Subtract the amount added
		health_to_add -= health_to_add as int
		
		if absorbing_health:
			leech_from_link_targets()
		
		if giving_health:
			give_blood()

func leech_from_link_targets():
	for link_target_name in link_targets:
		#print("trying to draw blood from: " + link_target_name)
		# If we are not max health and the target has leech ticks remaining
		if link_targets[link_target_name] > 0 and health < health_max:
			var link_target = server.players.get(int(link_target_name))
			# In case player has disconnected
			if link_target != null:
				link_target.emit_signal("method_called", "hit", [1])
				emit_signal("method_called", "hit", [-1])
			link_targets[link_target_name] -= 1

func give_blood():
	var link_target = server.players.get(int(most_recent_link_target))
	# If link target is on our team
	if link_target.team == team:
		link_target.emit_signal("method_called", "hit", [-5])
		emit_signal("method_called", "hit", [5])

func _physics_process(delta):
	if hit_scanning:
		var space_state = get_world_2d().direct_space_state
		# Only checks players b/c walls don't matter to sponge
		var raycast_result = space_state.intersect_ray(position, mouse_pos_current, [self], 63)
		print(raycast_result)
		# If we've chosen a player
		if raycast_result.has("collider"):
			var collided_name = raycast_result.get("collider").name
			link_targets[collided_name] = 10
			most_recent_link_target = collided_name
		else:
			reset_ability_and_cooldown(0)
		hit_scanning = false

func reset_ability_and_cooldown(ability_num: int):
	cooldown_timers[ability_num].start(0.01)

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String):
	mouse_pos_current = mouse_pos
	hit_scanning = true

func key_ability_0(ability_uuid: String):
	# toggles health absorption
	emit_signal("attribute_updated", "absorbing_health", !absorbing_health)

func key_ability_1(ability_uuid: String):
	# toggles giving health to latest link target
	emit_signal("attribute_updated", "giving_health", !giving_health)
