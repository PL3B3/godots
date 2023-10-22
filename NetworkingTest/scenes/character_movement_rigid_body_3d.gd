extends RigidBody3D

class_name CharacterMovementRigidBody

const SPEED = 6.0
const GROUND_ACCEL = 12.0
const AIR_ACCEL = 4.0
const GROUND_REVERSE_ACCEL_FACTOR = 1.0
const JUMP_HEIGHT: float = 2.0
const JUMP_DURATION: float = 0.32
const GRAVITY: float = (2.0 * JUMP_HEIGHT) / (pow(JUMP_DURATION, 2))
const JUMP_FORCE: float = GRAVITY * JUMP_DURATION
const UP = Vector3.UP
const DOWN = -UP 
const FLOOR_ANGLE:float = deg_to_rad(46)
const FLOOR_CHECK_DIST:float = 0.25
const MIN_CONTACT_DEPTH:float = 0.00001
const TOLERANCE:float = 0.01
const NOT_ON_FLOOR: Dictionary = {"normal": Vector3.ZERO, "position": Vector3.ZERO}
const FLOOR_CHECK_RADIUS:float = 0.5

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var next_head_position: Vector3 = head.position
@onready var last_head_position: Vector3 = head.position

var query_shape := SphereShape3D.new()
var tick = -1
var height = 2.0

func _ready():
	query_shape.radius = FLOOR_CHECK_RADIUS

func _process(delta):
	head.position = position
#	head.position = last_head_position.lerp(next_head_position, 0.5)
#	last_head_position = head.position

func move_and_update_view(player_input: Dictionary, delta: float, initial_physics_state: Dictionary = {}):
	head.rotation_degrees.y = player_input["yaw"]
	camera.rotation_degrees.x = player_input["pitch"]
	initial_physics_state = initial_physics_state if !initial_physics_state.is_empty() else get_physics_state()
	var state_after_move: Dictionary = move(initial_physics_state, player_input, delta)
	next_head_position = state_after_move["position"]
	return state_after_move

var order = 0
var integrating_forces = false
func _integrate_forces(state: PhysicsDirectBodyState3D):
#	cl_print([integrating_forces])
#	print("i ", get_world_3d().direct_space_state)
	if !integrating_forces:
		return
#	cl_print(['i', Time.get_ticks_msec(), linear_velocity])
#	print("i", order)
#	print("i", Time.get_ticks_usec())

#func _physics_process(delta):
#	print("p ", get_world_3d().direct_space_state)
#	print("p", order)
#	print("p", Time.get_ticks_usec())
#	order += 1
#	integrating_forces = true
#	PhysicsServer3D.simulate(delta)
#	integrating_forces = false

func move(initial_physics_state: Dictionary, player_input: Dictionary, delta: float) -> Dictionary:
#	return debug_move(player_input)
	var state_to_simulate: Dictionary = compute_movement(initial_physics_state, player_input, delta)
	return step_physics(state_to_simulate, delta)

func debug_move(player_input):
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(player_input["yaw"]))
	var direction = (facing_horizontal_direction_basis * Vector3(player_input["direction"].x, 0, player_input["direction"].y)).normalized()
	var debug_dir = direction + (
		Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	) * UP
	var debug_speed = 0.001 if Input.is_action_pressed("slow") else 0.1
	position += debug_dir * debug_speed
	
	var floor = find_floor({"position": position + Vector3.DOWN * 0.5})
	cl_print([floor, position])
	
	return get_physics_state()

var frames_since_grounded = 0
func compute_movement(initial_physics_state: Dictionary, player_input: Dictionary, delta: float) -> Dictionary:
	var next_velocity: Vector3 = initial_physics_state["velocity"]
	var next_position: Vector3 = initial_physics_state["position"]
	var h_velocity = Vector3(next_velocity.x, 0, next_velocity.z)
	var accel_factor = GROUND_ACCEL
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(player_input["yaw"]))
	var direction = (facing_horizontal_direction_basis * Vector3(player_input["direction"].x, 0, player_input["direction"].y)).normalized()
	var floor_contact = find_floor({"position": next_position + Vector3.DOWN * 0.5})
	if is_floor(floor_contact.normal):
		var target_velocity = project_vector_onto_plane_along_direction(direction * SPEED, floor_contact.normal, UP)
		next_velocity = next_velocity.lerp(target_velocity, GROUND_ACCEL * delta)
		if player_input["is_jumping"]:
			next_velocity.y = JUMP_FORCE
		elif frames_since_grounded > 5:
			var snap_motion = compute_snap_motion(floor_contact.position, floor_contact.normal, next_position)
			cl_print(["implied offset:", snap_motion, floor_contact, next_position])
			next_position += snap_motion
		frames_since_grounded += 1
	else:
		frames_since_grounded = 0
		if h_velocity.dot(direction) <= SPEED:
			next_velocity += (direction * (SPEED - h_velocity.dot(direction))) * AIR_ACCEL * delta
		next_velocity.y -= GRAVITY * delta
	
	return {
		"position": next_position,
		"velocity": next_velocity
	}

func set_physics_state(physics_state: Dictionary):
	position = physics_state["position"]
	linear_velocity = physics_state["velocity"]
	force_update_transform()

func step_physics(state_to_simulate: Dictionary, delta: float) -> Dictionary:
	set_physics_state(state_to_simulate)
#	cl_print(["b4:", state_to_simulate])
	integrating_forces = true
	PhysicsServer3D.simulate(delta)
	integrating_forces = false
	var state_after_movement = get_physics_state()
#	cl_print(["af:", state_after_movement])
	freeze_physics()
	return state_after_movement

func freeze_physics():
	# If we don't set it to zero, the next callback to _integrate_forces (by the engine) will apply the current velocity
	# What we want is physics to only really run when we explicitly call "step"
	linear_velocity = Vector3.ZERO

func get_physics_state() -> Dictionary:
	return {
		"position": position,
		"velocity": linear_velocity
	}

func simple_find_floor(point) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var raycast_down_result = space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			point, point + (DOWN * (height / 2 + 0.5)), 0xFFFFFFFF, [self]))
	return raycast_down_result if !raycast_down_result.is_empty() else NOT_ON_FLOOR

func compute_snap_motion(floor_point, floor_normal, actual_position):
	var implied_position_based_on_floor_contact = (floor_point + (floor_normal * FLOOR_CHECK_RADIUS)) + Vector3.UP * 0.5
	var implied_position_offset = implied_position_based_on_floor_contact - actual_position
#	cl_print(["implied offset:", implied_position_offset, floor_point, actual_position])
	if implied_position_offset.dot(UP) < -TOLERANCE:
		return 0.8 * (implied_position_offset.project(floor_normal) * (1 - TOLERANCE))
	else:
		return Vector3.ZERO

func find_floor(state):
	# ---- Static Test @ Start ----
	var start_pos = state.position
	var rest_contacts = get_rest_contacts(start_pos)
	var best_floor = best_floor(rest_contacts, start_pos)
	if best_floor != NOT_ON_FLOOR: return best_floor
	# ---- Sweep Test ----
	var motion = cast_sphere(start_pos, DOWN * FLOOR_CHECK_DIST)
	var end_pos = start_pos + DOWN * ((FLOOR_CHECK_DIST * motion[1]) + TOLERANCE)
	rest_contacts = get_rest_contacts(end_pos)
	best_floor = best_floor(rest_contacts, end_pos, 1.0 - motion[1])
	return best_floor

func best_floor(contacts: Array, current_position, motion_left=FLOOR_CHECK_DIST, iters=3):
	if not contacts: return NOT_ON_FLOOR
	contacts.sort_custom(self.compare_contact_flatness)
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
			var wall_result = find_wall_floor(contacts[i], motion_left, current_position)
			if is_floor(wall_result.normal):
				return wall_result
	return NOT_ON_FLOOR

func find_wall_floor(contact, motion_left, current_position):
	"""
	find floor at base of wall by simulating a spherecast down the wall
	- motion_left: max distance the 'spherecast' can travel
	returns floor contact if found, else {}
	"""
	# offset along normal to avoid raycast hitting wall
	var hit_point = contact.position + contact.normal * TOLERANCE
	var start_pos = contact.position + contact.normal * FLOOR_CHECK_RADIUS
	var down_wall_dir = Plane(contact.normal, 0).project(DOWN).normalized()
	var down_wall_ray = down_wall_dir * 10
	var space_state = get_world_3d().direct_space_state
	for point in [hit_point, start_pos]:
		var ray_query_params = PhysicsRayQueryParameters3D.create(point, point + down_wall_ray, 0xFFFFFFFF, [self])
		var base_hit = space_state.intersect_ray(ray_query_params)
		if base_hit and is_floor(base_hit.normal):
			var floor_hit = verify_sphere_contact(
				start_pos, down_wall_dir, base_hit.normal, motion_left)
			if floor_hit != NOT_ON_FLOOR:
				var hit_pos = floor_hit.position + floor_hit.normal * FLOOR_CHECK_RADIUS
#				state.transform.origin = state.transform.origin.linear_interpolate(
#					hit_pos, 0.9)
				return floor_hit
#			var base_normal = base_hit.normal
#			var contact_point = start_pos + (-base_normal * FLOOR_CHECK_RADIUS)
#			# offset ray start in case contact_point is inside floor
#			var floor_hit = space_state.intersect_ray(
#				contact_point - down_wall_dir * 0.01, 
#				contact_point + down_wall_ray, [self])
#			if (floor_hit and 
#				floor_hit.normal.distance_to(base_normal) < TOLERANCE and
#				floor_hit.point.distance_to(contact_point) < motion_left):
#				return {"normal": base_normal, "point": floor_hit.position}
	return NOT_ON_FLOOR

func verify_sphere_contact(point, direction, normal, distance=FLOOR_CHECK_DIST, radius=FLOOR_CHECK_RADIUS):
	# use raycast to check if a spherecast would collide at the given normal
	var space_state = get_world_3d().direct_space_state
	var contact_point = point + (-normal * radius)
	# offset a bit in case contact_point is inside another shape
	var contact_hit = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		contact_point - direction * TOLERANCE, 
		contact_point + direction * distance, 
		0xFFFFFFFF,
		[self]))
	if contact_hit and contact_hit.normal.distance_to(normal) < TOLERANCE:
		return {"normal": normal, "position": contact_hit.position}
	return NOT_ON_FLOOR

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
		contacts.append({"normal": contact_vec.normalized(), "position": outer_point})
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

func cast_sphere(position, motion, radius=0.5):
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	return cast_motion(position, motion, sphere)

func CalculateMovementDirection(input, current_transform, up_direction):
	var raw_direction = Vector3(input.direction.x, 0, input.direction.y)
	var direction = (transform.basis * raw_direction).normalized()
	return direction.rotated(up_direction, deg_to_rad(input.yaw))

func CalculateGroundAcceleration(target_velocity, current_velocity, delta):
	var is_accelerating_in_opposite_direction_of_motion = target_velocity.dot(current_velocity) <= 0
	if is_accelerating_in_opposite_direction_of_motion:
		return GROUND_ACCEL * delta * GROUND_REVERSE_ACCEL_FACTOR 
	else:
		return GROUND_ACCEL * delta

func project_vector_onto_plane_along_direction(vector, plane_normal, direction):
	var distance_to_plane_from_vector_along_direction = -1.0 * (plane_normal.dot(vector) / plane_normal.dot(direction))
	var estimated_projected_vector = vector + direction * distance_to_plane_from_vector_along_direction
	var exact_projected_vector = Plane(plane_normal, 0).project(estimated_projected_vector)
	return exact_projected_vector

func cl_print(items: Array):
	var print_str = "CL:"
	for item in items:
		print_str = print_str + " " + str(item)
	if !multiplayer.is_server():
		print(print_str)
