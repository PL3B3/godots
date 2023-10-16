extends Node3D

class_name FloorFinder

const UP = Vector3.UP
const DOWN = -UP 
const FLOOR_ANGLE:float = deg_to_rad(46)
const FLOOR_CHECK_DIST:float = 0.25
const MIN_CONTACT_DEPTH:float = 0.00001
const TOLERANCE:float = 0.01

var query_shape := SphereShape3D.new()
var body_radius = 1


func find_floor(state):
	# ---- Static Test @ Start ----
	var start_pos = state.transform.origin
	var rest_contacts = get_rest_contacts(start_pos)
	var best_floor = best_floor(rest_contacts, start_pos, state)
	if best_floor: return best_floor
	# ---- Sweep Test ----
	var motion = cast_sphere(start_pos, DOWN * FLOOR_CHECK_DIST)
	var end_pos = start_pos + DOWN * ((FLOOR_CHECK_DIST * motion[1]) + TOLERANCE)
	rest_contacts = get_rest_contacts(end_pos)
	best_floor = best_floor(rest_contacts, end_pos, state, 1.0 - motion[1])
	if best_floor: return best_floor
	return {}

func best_floor(contacts, position, state, motion_left=FLOOR_CHECK_DIST, iters=3):
	if not contacts: return {}
	contacts.sort_custom(self, "compare_contact_flatness")
	var closest = contacts[0]
	for contact in contacts:
		if is_floor(contact.normal):
			var curr_distance = contact.point.distance_to(state.transform.origin)
			var best_distance = closest.point.distance_to(state.transform.origin)
			if curr_distance < best_distance - 0.001:
				closest = contact
	if is_floor(closest.normal): return closest
	# reach here -> contacts are all walls or ceilings
	for i in range(min(iters, len(contacts))):
		if is_ceil(contacts[i].point): return {}
		else: # wall
			var wall_result = find_wall_floor(contacts[i], motion_left, state)
			if wall_result and is_floor(wall_result.normal):
				return wall_result
	return {}

func find_wall_floor(contact, motion_left, state):
	"""
	find floor at base of wall by simulating a spherecast down the wall
	- motion_left: max distance the 'spherecast' can travel
	returns floor contact if found, else {}
	"""
	# offset along normal to avoid raycast hitting wall
	var hit_point = contact.point + contact.normal * TOLERANCE
	var start_pos = contact.point + contact.normal * body_radius
	var down_wall_dir = Plane(contact.normal, 0).project(DOWN).normalized()
	var down_wall_ray = down_wall_dir * 10
	var space_state = get_world_3d().direct_space_state
	for point in [hit_point, start_pos]:
		var ray_query_params = PhysicsRayQueryParameters3D.create(point, point + down_wall_ray, 0xFFFFFFFF, [self])
		var base_hit = space_state.intersect_ray(ray_query_params)
		if base_hit and is_floor(base_hit.normal):
			var floor_hit = verify_sphere_contact(
				start_pos, down_wall_dir, base_hit.normal, motion_left)
			if floor_hit: 
				var hit_pos = floor_hit.point + floor_hit.normal * body_radius
#				state.transform.origin = state.transform.origin.linear_interpolate(
#					hit_pos, 0.9)
				return floor_hit
#			var base_normal = base_hit.normal
#			var contact_point = start_pos + (-base_normal * body_radius)
#			# offset ray start in case contact_point is inside floor
#			var floor_hit = space_state.intersect_ray(
#				contact_point - down_wall_dir * 0.01, 
#				contact_point + down_wall_ray, [self])
#			if (floor_hit and 
#				floor_hit.normal.distance_to(base_normal) < TOLERANCE and
#				floor_hit.point.distance_to(contact_point) < motion_left):
#				return {"normal": base_normal, "point": floor_hit.position}
	return {}

func verify_sphere_contact(position, direction, normal, distance=FLOOR_CHECK_DIST, radius=body_radius):
	# use raycast to check if a spherecast would collide at the given normal
	var space_state = get_world_3d().direct_space_state
	var contact_point = position + (-normal * radius)
	# offset a bit in case contact_point is inside another shape
	var contact_hit = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		contact_point - direction * TOLERANCE, 
		contact_point + direction * distance, 
		0xFFFFFFFF,
		[self]))
	if contact_hit and contact_hit.normal.distance_to(normal) < TOLERANCE:
		return {"normal": normal, "point": contact_hit.position}
	return {}

func is_floor(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) <= FLOOR_ANGLE + TOLERANCE

func is_ceil(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) >= PI/2 + TOLERANCE

func compare_contact_flatness(a, b):
	return a.normal.dot(UP) >= b.normal.dot(UP)

func get_rest_contacts(position, shape=query_shape):
	# return list of {normal, point}
	var contacts = []
	var space_state = get_world_3d().direct_space_state
	# margin is used to mimic get_rest_info
	var points = collision_points(position, shape, 0.0001)
	for i in range(len(points) / 2):
		var inner_point = points[i * 2]
		var outer_point = points[i * 2 + 1]
		var contact_depth = outer_point.distance_to(inner_point)
		var contact_vec:Vector3
		if contact_depth >= MIN_CONTACT_DEPTH:
			contact_vec = outer_point - inner_point
		else:
			if shape.get_class() == "SphereShape":
				contact_vec = position - inner_point
			else:
				var ray_end = position + (outer_point - position) * (1 + TOLERANCE)
				var ray_query_params = PhysicsRayQueryParameters3D.create(position, ray_end, 0xFFFFFFFF, [self])
				var hit = space_state.intersect_ray(ray_query_params)
				if hit:
					contact_vec = hit.normal
				else:
					contact_vec = position - inner_point
		contacts.append({"normal": contact_vec.normalized(), "point": outer_point})
	return contacts

func collision_points(position, shape=query_shape, margin=0):
	var space_state = get_world_3d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.exclude = [self]
	shape_query.set_shape(shape)
	shape_query.margin = margin
	shape_query.transform.origin = position
	return space_state.collide_shape(shape_query)

func cast_motion(position, motion, shape):
	var space_state = get_world_3d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.exclude = [self]
	shape_query.set_shape(shape)
	shape_query.motion = motion
	shape_query.transform.origin = position
	return space_state.cast_motion(shape_query)

func cast_sphere(position, motion, radius=1):
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	return cast_motion(position, motion, sphere)

