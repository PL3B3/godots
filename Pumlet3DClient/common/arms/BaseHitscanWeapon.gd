extends "res://common/arms/BaseWeapon.gd"

onready var mesh = $MeshInstance
var rng = RandomNumberGenerator.new()
var fire_line_mesh
var fire_line_clear_timer

var fire_mode_settings
var fire_mode_phys_processing = [false, false, false]
var ignored_objects = []
var velocity_push_factor_universal = 10

signal recoil(direction, speed, ticks)

func _ready():
	fire_line_clear_timer = Timer.new()
	fire_line_clear_timer.set_one_shot(true)
	fire_line_clear_timer.connect("timeout", self, "_clear_fire_lines")
	add_child(fire_line_clear_timer)
	fire_line_mesh = ImmediateGeometry.new()
	var line_material = SpatialMaterial.new()
	line_material.set_albedo(Color.gold)
	line_material.set_feature(SpatialMaterial.FEATURE_EMISSION, true)
	line_material.set_emission(Color.orange)
	fire_line_mesh.set_material_override(line_material)
	rng.randomize()

func init():
#	fire_rate_default = 1.3
#	reload_time_default = 3
	fire_rate_default = 0.1
	reload_time_default = 1
	clip_size_default = 400
	clip_remaining = clip_size_default
	ammo_default = 2000
	ammo_remaining = ammo_default
	fire_mode_settings = [
		{
			"pattern": {
				Vector3(0, 0, 0): 5,
				Vector3(-0.035, 0, 0): 3,
				Vector3(-0.0125, 0.0125, 0): 4,
				Vector3(0, 0.035, 0): 3,
				Vector3(-0.0125, -0.0125, 0): 4,
				Vector3(0.035, 0, 0): 3,
				Vector3(0.0125, 0.0125, 0): 4,
				Vector3(0, -0.035, 0): 3,
				Vector3(0.0125, -0.0125, 0): 4},
			"transform": null,
			"parameters": [],
			"range": 30,
			"damage_falloff": 0.3,
			"push_force_falloff": 0.3,
			"self_push_speed": 0.5,
			"self_push_ticks": 10,
			"target_push_speed": 0.1,
			"target_push_ticks": 10,
			"velocity_push_factor": 0.1
		},
		{
			"pattern": {
				Vector3(-.20, 0, 0): 16,
				Vector3(-0.15, 0, 0): 16,
				Vector3(-0.10, 0, 0): 16,
				Vector3(-0.05, 0, 0): 16,
				Vector3(-0.015, 0, 0): 16,
				Vector3(0.015, 0, 0): 16,
				Vector3(0.2, 0, 0): 16,
				Vector3(0.15, 0, 0): 16,
				Vector3(0.1, 0, 0): 16,
				Vector3(0.05, 0, 0): 16},
			"transform": null,
			"parameters": [],
			"range": 10,
			"damage_falloff": 3.5,
			"push_force_falloff": 1,
			"self_push_speed": 3,
			"self_push_ticks": 10,
			"target_push_speed": 0.25,
			"target_push_ticks": 10,
			"velocity_push_factor": 0.2
		},
		{
			"pattern": {
				Vector3(0, 0, 0): 35},
			"transform": null,
			"parameters": [],
			"range": 60,
			"damage_falloff": 5,
			"push_force_falloff": -2,
			"self_push_speed": -1,
			"self_push_ticks": 15,
			"target_push_speed": -1,
			"target_push_ticks": 10,
			"velocity_push_factor": 0.3
		}]

func _process(delta):
	pass

func primary_fire(fire_transform: Transform, fire_parameters):
	fire_by_mode(0, fire_transform, fire_parameters)
	fire_audio_player.set_stream(load("res://assets/arms/primary_fire.wav"))
	fire_audio_player.play()

func secondary_fire(fire_transform: Transform, fire_parameters):
	fire_by_mode(1, fire_transform, fire_parameters)
	fire_audio_player.set_stream(load("res://assets/arms/shot.wav"))
	fire_audio_player.play()

func tertiary_fire(fire_transform: Transform, fire_parameters):
	fire_by_mode(2, fire_transform, fire_parameters)
	fire_audio_player.set_stream(load("res://assets/arms/woosh.wav"))
	fire_audio_player.play(0.3)

func fire_by_mode(mode: int, fire_transform: Transform, fire_parameters):
	fire_mode_phys_processing[mode] = true
	fire_mode_settings[mode]["transform"] = fire_transform
	fire_mode_settings[mode]["parameters"] = fire_parameters

func hitscan_fire(mode: int) -> Dictionary:
	var physics_state = get_world().direct_space_state
	
	var collision_dict = {}
	var fire_lines = []
	var total_damage = 0
	
	var fire_settings = fire_mode_settings[mode]
	var fire_transform = fire_settings["transform"]
	var fire_pattern = fire_settings["pattern"]
	
	#print(fire_transform.basis.z)
	
	for offset in fire_pattern:
		var fire_direction = -fire_settings["range"] * (
			fire_transform.basis.z + 
			fire_transform.basis.x * offset.x +
			fire_transform.basis.y * offset.y +
			fire_transform.basis.z * offset.z)
		
		var collision = physics_state.intersect_ray(
			fire_transform.origin,
			fire_direction + fire_transform.origin,
			ignored_objects)
		
		collision_dict[offset] = collision
		
		if not collision.empty():
			fire_lines.append(collision.position - fire_transform.origin)
			var dist_ratio = (
				(collision.position - fire_transform.origin).length() / 
				fire_settings["range"])
			#print("collided with " + collision.collider.name)
			if collision.collider.has_method("hit"):
				var damage_falloff = exp(-1 * fire_settings["damage_falloff"] * dist_ratio)
				var damage = fire_pattern[offset] * damage_falloff
				total_damage += damage
				collision.collider.callv(
					"hit", 
					[damage])
			if collision.collider.has_method("dash"):
				var push_force_falloff = exp(-1 * fire_settings["push_force_falloff"] * dist_ratio)
				var push_speed = fire_settings["target_push_speed"] * push_force_falloff
				collision.collider.callv("dash", [
					(fire_direction.normalized() + (
						(
							velocity * 
							(push_speed / abs(push_speed)) /
							velocity_push_factor_universal) * 
						fire_settings["velocity_push_factor"])),
					push_speed,
					fire_settings["target_push_ticks"]
				])
		else:
			fire_lines.append(fire_direction)
	
	emit_signal("recoil",
		fire_transform.basis.z,
		fire_settings["self_push_speed"],
		fire_settings["self_push_ticks"])
	manifest_fire(fire_settings["self_push_speed"], fire_transform.origin, fire_lines)
	
	#print("This shot dealt " + str(total_damage) + " damage")
	emit_signal("dealt_damage", total_damage)
	
	return collision_dict

func manifest_fire(power: float, origin: Vector3, fire_lines):
	animate_fire(power)
	create_fire_lines_representation(origin, fire_lines)

func animate_fire(power: float):
	var recoiled_position = mesh.get_translation() + Vector3(0, 0, sqrt(abs(power) / 10))
	animation_helper.interpolate_symmetric(
		interpolator,
		mesh,
		"translation",
		recoiled_position,
		0.8)
	if not clip_remaining == 0:
		yield(get_tree().create_timer(0.55), "timeout")
		load_audio_player.set_stream(load("res://assets/arms/shotgun_pump.wav"))
		load_audio_player.play()

func create_fire_lines_representation(origin, fire_lines):
	if not fire_lines:
		return
	var verts = PoolVector3Array()
	if not get_node("/root").has_node(fire_line_mesh.name):
		get_node("/root").add_child(fire_line_mesh)
	
	for line in fire_lines:
		verts.append(origin)
		verts.append(origin + line)
	fire_line_mesh.begin(Mesh.PRIMITIVE_LINES)
	for vert in verts:
		fire_line_mesh.add_vertex(vert)
	fire_line_mesh.end()
	fire_line_clear_timer.start(fire_rate_default)

func animate_reload():
	if not ammo_remaining == 0:
		var new_rot = mesh.rotation_degrees + Vector3(30, 0, 0)
		animation_helper.interpolate_symmetric(
			interpolator,
			mesh,
			"rotation_degrees",
			new_rot,
			reload_time_default)
		yield(get_tree().create_timer(0.5 * reload_time_default), "timeout")
		load_audio_player.set_stream(load("res://assets/arms/reload.wav"))
		load_audio_player.play()
		yield(get_tree().create_timer(0.4), "timeout")
		load_audio_player.set_stream(load("res://assets/arms/shotgun_pump.wav"))
		load_audio_player.play()

func _clear_fire_lines():
	fire_line_mesh.clear()
	get_node("/root").remove_child(fire_line_mesh)

var last_position = Vector3()
var velocity = 0
func _physics_process(delta):
	var current_position = get_global_transform().origin
	velocity = (current_position - last_position) / delta
	last_position = current_position
	for mode in range(len(fire_mode_phys_processing)):
		if fire_mode_phys_processing[mode]:
			hitscan_fire(mode)
			fire_mode_phys_processing[mode] = false
