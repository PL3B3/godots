extends Object

class_name FloorCheck

const UP = Vector3.UP
const DOWN = -UP 
const NOT_ON_FLOOR: Dictionary = {"normal": Vector3.ZERO, "position": Vector3.ZERO}
const FLOOR_CHECK_DIST:float = 1
const FLOOR_CHECK_TOLERANCE:float = 0.01
const FLOOR_ANGLE:float = deg_to_rad(46)
const MIN_FLOOR_CONTACT_DEPTH:float = 0.00001
const ALL_COLLISION_LAYERS_MASK = 0xFFFFFFFF

var _physics_space_state: PhysicsDirectSpaceState3D
var _collision_sphere: SphereShape3D
var _collision_radius: float
var _is_logging_enabled: bool
var _excluded_colliders: Array

func _init(physics_space_state, collision_radius, excluded_colliders, is_logging_enabled=false):
	_physics_space_state = physics_space_state
	_collision_radius = collision_radius
	_collision_sphere = SphereShape3D.new()
	_collision_sphere.radius = _collision_radius
	_excluded_colliders = excluded_colliders
	_is_logging_enabled = is_logging_enabled

func find_floor(start_pos: Vector3, floor_check_distance: float):
	# ---- Resting Test ----
	var rest_contacts = get_rest_contacts(start_pos)
	var best_floor = best_floor(rest_contacts, start_pos, floor_check_distance)
	if _is_logging_enabled:
		print("rest contacts", rest_contacts, "\nbest floor", best_floor)
	if best_floor != NOT_ON_FLOOR: return best_floor
	# ---- Downward Sphere Sweep Test ----
	var motion = cast_sphere(start_pos, DOWN * floor_check_distance)
	var end_pos = start_pos + DOWN * ((floor_check_distance * motion[1]) + FLOOR_CHECK_TOLERANCE)
	var post_sweep_rest_contacts = get_rest_contacts(end_pos)
	if _is_logging_enabled:
		print("sweep motion", motion, "\nmotion contacts", post_sweep_rest_contacts, "\nbest floor", best_floor)
	# ---- Check for floor at base of wall ----
	var motion_left_for_wall_check = (1.0 - motion[1]) * floor_check_distance
	best_floor = best_floor(post_sweep_rest_contacts, end_pos, motion_left_for_wall_check)
	return best_floor

func best_floor(contacts: Array, current_position, motion_left, iters=3):
	if not contacts: return NOT_ON_FLOOR
	contacts.sort_custom(compare_contact_flatness)
	var closest = contacts[0]
	for contact in contacts:
		if is_floor(contact.normal):
			var curr_distance = contact.position.distance_to(current_position)
			var best_distance = closest.position.distance_to(current_position)
			if curr_distance < best_distance - 0.001:
				closest = contact
	if is_floor(closest.normal): return closest
	# reach here -> contacts are all walls or ceilings
	for i in range(min(iters, len(contacts))):
		if is_ceil(contacts[i].position): return {}
		else: # wall
			var wall_result = find_wall_floor(contacts[i], motion_left)
			if is_floor(wall_result.normal):
				return wall_result
	return NOT_ON_FLOOR

func find_wall_floor(wall_contact, motion_left):
	# find floor at base of wall by simulating a spherecast down the wall
	# offset along normal to avoid raycast hitting wall
	var hit_point = wall_contact.position + wall_contact.normal * FLOOR_CHECK_TOLERANCE
	var start_pos = wall_contact.position + wall_contact.normal * _collision_radius
	var down_wall_dir = Plane(wall_contact.normal, 0).project(DOWN).normalized()
	var down_wall_ray = down_wall_dir * 10
	for point in [hit_point, start_pos]:
		var ray_query_params = PhysicsRayQueryParameters3D.create(
			point, point + down_wall_ray, ALL_COLLISION_LAYERS_MASK, _excluded_colliders)
		var base_hit = _physics_space_state.intersect_ray(ray_query_params)
		if base_hit and is_floor(base_hit.normal):
			var floor_hit = verify_sphere_contact(start_pos, down_wall_dir, base_hit.normal, motion_left)
			if floor_hit != NOT_ON_FLOOR:
				return floor_hit
	return NOT_ON_FLOOR

func verify_sphere_contact(position, sweep_direction, normal, distance):
	# use raycast to check if a spherecast would collide at the given normal
	var contact_point = position + (-normal * _collision_radius)
	# offset a bit in case contact_point is inside another shape
	var contact_hit = _physics_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			contact_point - sweep_direction * FLOOR_CHECK_TOLERANCE, 
			contact_point + sweep_direction * distance, 
			ALL_COLLISION_LAYERS_MASK,
			_excluded_colliders))
	if contact_hit and contact_hit.normal.dot(normal) > (1 - FLOOR_CHECK_TOLERANCE):
		return {"normal": normal, "position": contact_hit.position}
	return NOT_ON_FLOOR

func get_rest_contacts(position):
	# return list of {normal, point}
	var contacts = []
	# margin is used to mimic get_rest_info
	var points = collision_points(position)
	for i in range(len(points) / 2):
		var inner_point = points[i * 2]
		var outer_point = points[i * 2 + 1]
		var contact_depth = outer_point.distance_to(inner_point)
		var contact_vec:Vector3
		if contact_depth >= MIN_FLOOR_CONTACT_DEPTH:
			contact_vec = outer_point - inner_point
		else:
			contact_vec = position - inner_point
		contacts.append({"normal": contact_vec.normalized(), "position": outer_point})
	return contacts

func collision_points(position):
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.exclude = _excluded_colliders
	shape_query.set_shape(_collision_sphere)
	shape_query.margin = 0.0001
	shape_query.transform.origin = position
	return _physics_space_state.collide_shape(shape_query)

func cast_sphere(position, motion):
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.exclude = _excluded_colliders
	shape_query.set_shape(_collision_sphere)
	shape_query.motion = motion
	shape_query.transform.origin = position
	return _physics_space_state.cast_motion(shape_query)

func log(items):
	if _is_logging_enabled:
		var print_str = "% -- FloorCheck: " % [Time.get_datetime_string_from_system()]
		for item in items:
			print_str = print_str + " " + str(item)
		print(print_str)

static func is_floor(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) <= FLOOR_ANGLE + FLOOR_CHECK_TOLERANCE

static func is_ceil(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) >= PI/2 + FLOOR_CHECK_TOLERANCE

static func compare_contact_flatness(a, b):
	return a.normal.dot(UP) >= b.normal.dot(UP)
