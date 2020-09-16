extends "res://arms/base/BaseWeapon.gd"

onready var mesh = $MeshInstance
var rng = RandomNumberGenerator.new()
var fire_line_mesh
var fire_line_clear_timer

var fire_mode_settings = [
	{
		"pattern": {
			Vector3(0, 0, 0): 10,
			Vector3(-0.035, 0, 0): 5,
			Vector3(-0.0125, 0.0125, 0): 8,
			Vector3(0, 0.035, 0): 5,
			Vector3(-0.0125, -0.0125, 0): 8,
			Vector3(0.035, 0, 0): 5,
			Vector3(0.0125, 0.0125, 0): 8,
			Vector3(0, -0.035, 0): 5,
			Vector3(0.0125, -0.0125, 0): 8},
		"transform": null,
		"parameters": [],
		"range": 30,
		"self_push_speed": 1,
		"target_push_speed": 0.3
	},
	{
		"pattern": {
			Vector3(-.20, 0, 0): 10,
			Vector3(-0.15, 0, 0): 10,
			Vector3(-0.10, 0, 0): 10,
			Vector3(-0.05, 0, 0): 10,
			Vector3(0, 0, 0): 10,
			Vector3(0.2, 0, 0): 10,
			Vector3(0.15, 0, 0): 10,
			Vector3(0.1, 0, 0): 10,
			Vector3(0.05, 0, 0): 10},
		"transform": null,
		"parameters": [],
		"range": 15,
		"self_push_speed": 6,
		"target_push_speed": 1
	},
	{
		"pattern": {
			Vector3(0, 0, 0): 35},
		"transform": null,
		"parameters": [],
		"range": 60,
		"self_push_speed": 0,
		"target_push_speed": 0
	}]
var push_ticks = 10
var fire_mode_phys_processing = [false, false, false]
var ignored_objects = []


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
	fire_rate_default = 0.6
	reload_time_default = 1.6
	clip_size_default = 2
	clip_remaining = clip_size_default
	ammo_default = 40
	ammo_remaining = ammo_default

func _process(delta):
	pass

func primary_fire(fire_transform: Transform, fire_parameters):
	fire_by_mode(0, fire_transform, fire_parameters)

func secondary_fire(fire_transform: Transform, fire_parameters):
	fire_by_mode(1, fire_transform, fire_parameters)

func tertiary_fire(fire_transform: Transform, fire_parameters):
	fire_by_mode(2, fire_transform, fire_parameters)

func fire_by_mode(mode: int, fire_transform: Transform, fire_parameters):
	fire_mode_phys_processing[mode] = true
	fire_mode_settings[mode]["transform"] = fire_transform
	fire_mode_settings[mode]["parameters"] = fire_parameters

func hitscan_fire(mode: int) -> Dictionary:
	var physics_state = get_world().direct_space_state
	
	var collision_dict = {}
	var fire_lines = []
	
	var fire_settings = fire_mode_settings[mode]
	var fire_transform = fire_settings["transform"]
	var fire_pattern = fire_settings["pattern"]
	
	print(fire_transform.basis.z)
	
	for offset in fire_pattern:
		var damage = fire_pattern[offset]
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
		fire_lines.append(fire_direction)
		
		if not collision.empty():
			fire_lines.append(collision.position - fire_transform.origin)
			#print("collided with " + collision.collider.name)
			if collision.collider.has_method("hit"):
				collision.collider.callv("hit", [damage])
			if collision.collider.has_method("dash"):
				collision.collider.callv("dash", [
					-collision.normal,
					fire_settings["target_push_speed"],
					push_ticks
				])
	
	
	emit_signal("recoil",
		fire_transform.basis.z,
		fire_settings["self_push_speed"],
		push_ticks)
	animate_recoil(fire_settings["self_push_speed"])
	
	create_fire_lines_representation(fire_transform.origin, fire_lines)
	
	return collision_dict

func create_fire_lines_representation(origin, fire_lines):
	var verts = PoolVector3Array()
	get_node("/root").add_child(fire_line_mesh)
	for line in fire_lines:
		verts.append(origin)
		verts.append(origin + line)
	fire_line_mesh.begin(Mesh.PRIMITIVE_LINES)
	for vert in verts:
		fire_line_mesh.add_vertex(vert)
	fire_line_mesh.end()
	fire_line_clear_timer.start(fire_rate_default * 2)

func animate_recoil(power: float):
	var idle_position = mesh.get_translation()
	var recoiled_position = idle_position + Vector3(0, 0, sqrt(power / 10))
	interpolator.interpolate_property(mesh, "translation", idle_position, recoiled_position, fire_rate_default / 2, Tween.TRANS_CUBIC)
	interpolator.start()
	yield(interpolator,"tween_completed")
	interpolator.interpolate_property(mesh, "translation", recoiled_position, idle_position, fire_rate_default / 2, Tween.TRANS_CUBIC)
	interpolator.start()

func _clear_fire_lines():
	fire_line_mesh.clear()
	get_node("/root").remove_child(fire_line_mesh)

func _physics_process(delta):
	for mode in range(len(fire_mode_phys_processing)):
		if fire_mode_phys_processing[mode]:
			hitscan_fire(mode)
			fire_mode_phys_processing[mode] = false
