extends "res://character/base_character/ChubbyCharacter.gd"


var health_max : int = 120
var mouse_pos_current := Vector2()
var hit_scanning := false
#var link_target : KinematicBody2D = null
var link_targets = {} # keys are string ID's of targeted players, values are how many seconds of blood we can draw
var most_recent_link_target : String # name of latest targetted player
var absorbing_health = false
var giving_health = false

func _ready():
	health = 20
	health_cap = 20
	cooldowns[0] = 4
	cooldowns[2] = 0.5
	cooldowns[3] = 0.5

func _physics_process(delta):
	pass
	"""
	if hit_scanning:
		var space_state = get_world_2d().direct_space_state
		# Only checks players b/c walls don't matter to sponge
		var raycast_result = space_state.intersect_ray(position, mouse_pos_current, [self], 63)
		print(raycast_result)
		# If we've chosen a player
		if raycast_result.has("collider"):
			link_targets[raycast_result.get("collider").name] = 10
		hit_scanning = false
	"""

func mouse_ability_0(mouse_pos: Vector2, ability_uuid: String):
	"""
	mouse_pos_current = mouse_pos
	hit_scanning = true
	"""
	pass

func key_ability_0(ability_uuid: String):
	# toggles health absorption
	#absorbing_health = !absorbing_health
	pass
