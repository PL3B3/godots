extends CharacterBody3D

const COLLISION_RADIUS = 2.5
const SPEED = COLLISION_RADIUS * 10
const GROUND_ACCEL = 10
const AIR_ACCEL = 4
const JUMP_HEIGHT: float = 2 * COLLISION_RADIUS
const JUMP_DURATION: float = 0.33
const GRAVITY: float = (2.0 * JUMP_HEIGHT) / (pow(JUMP_DURATION, 2))
const JUMP_FORCE: float = GRAVITY * JUMP_DURATION
const TOLERANCE:float = 0.01
const FULL_ROTATION_DEGREES = 360
const MOUSE_SENSITIVITY = 0.1

@onready var debug_sphere = preload("res://scenes/debug_sphere.tscn")
@onready var start_position = global_position
@onready var camera = $Camera3D
@onready var last_position = global_position 
var player_gravity: float = 0
var _yaw: float = 0
var _pitch: float = 0
var is_simulate = false


#func _ready():
#	collision_shape.radius = COLLISION_RADIUS
#	smaller_collision_shape.radius = COLLISION_RADIUS - SKIN_DEPTH
#	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if (event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		_yaw = normalize_angle_to_positive_degrees(_yaw - (event.relative.x) * MOUSE_SENSITIVITY)
		_pitch = clamp(_pitch - (event.relative.y * MOUSE_SENSITIVITY), -90.0, 90.0)
		#print("new yaw: ", _yaw, " + new pitch: ", _pitch)
	elif event.is_action_pressed("toggle_mouse_mode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	#_yaw += 1
	var frame_lerped_position = last_position.lerp(global_position, Engine.get_physics_interpolation_fraction())
	#var predicted_position = position + (position - last_position) * Engine.get_physics_interpolation_fraction()
	camera.global_position = frame_lerped_position + Vector3(0, COLLISION_RADIUS * 0.5, 0)
	#camera.rotation_degrees.y = _yaw
	#camera.rotation_degrees.x = _pitch
	
	# There are two layers of "issues" contributing to the jitter when moving and rotating
	# One is syncing up to the physics interp frac (I think)
	# Other is intrinsic jitteriness of mouse input
	
	var current_rotation_basis = Quaternion(Basis.IDENTITY.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0)))
	#var interpolated_rotation_basis = Quaternion(last_camera_basis).slerp(current_rotation_basis,  Engine.get_physics_interpolation_fraction())
	var interpolated_rotation_basis = Quaternion(last_camera_basis).slerp(Quaternion(current_camera_basis),  Engine.get_physics_interpolation_fraction())
	#var interpolated_rotation_basis = Quaternion(camera.basis).slerp(Quaternion(current_rotation_basis),  Engine.get_physics_interpolation_fraction())
	camera.basis = Basis(Quaternion(camera.basis).slerp(interpolated_rotation_basis, 0.5))
	
	$MeshMount.rotation_degrees.y = _yaw

var counter = 0
@onready var last_camera_basis = camera.basis
@onready var current_camera_basis = camera.basis
func _physics_process(delta):
	last_camera_basis = current_camera_basis
	current_camera_basis = Basis.IDENTITY.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0))
	#print(Quaternion(current_camera_basis).angle_to(Quaternion(last_camera_basis)))
	last_position = global_position
	if is_simulate:
		run_simulation(delta)
	else:
		player_move(delta)

func is_valid_floor(floor_contact):
	if is_moving_along_floor:
		return is_floor(floor_contact.normal)
	else:
		return is_floor(floor_contact.normal) && compute_vertical_distance_from_floor(floor_contact, global_position) < 0.05

var player_velocity = Vector3()
var frames_since_grounded = 0
var last_floor_normal = Vector3()
var is_moving_along_floor = false
func player_move(delta):
	var h_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(_yaw))
	var vertical_direction = Input.get_axis("move_down", "move_up")
	var direction = (facing_horizontal_direction_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	$DebugLabels/DebugLabel1.text = "HORIZONTAL_SPEED: %f" % h_velocity.length()
	var floor_contact = find_floor(global_position, 1.0 if is_moving_along_floor else 0.01)
	#print(vtos(floor_contact.normal))
	if is_floor(floor_contact.normal):
		var target_velocity = project_vector_onto_plane_along_direction(direction * SPEED, floor_contact.normal, UP)
		player_velocity = player_velocity.lerp(target_velocity, GROUND_ACCEL * delta)
		if Input.is_action_pressed("move_up"):
			player_velocity.y = JUMP_FORCE
			is_moving_along_floor = false
		elif Input.is_action_pressed("move_down"):
			player_velocity.y = 2 * JUMP_FORCE
			player_velocity += 50 * direction
			is_moving_along_floor = false
		else:
			is_moving_along_floor = true
			global_position += compute_snap_motion(floor_contact.position, floor_contact.normal, global_position, player_velocity)
		frames_since_grounded += 1
	else:
		is_moving_along_floor = false
		frames_since_grounded = 0
		var fraction_to_turn = 0.2
		if (direction.dot(h_velocity.normalized()) > 0): # don't want to turn backwards
			var turn_direction = h_velocity.normalized().slerp(direction, 3 * delta)
#			var direction_after_turn = ((h_velocity_length * fraction_to_turn * turn_direction) + (h_velocity * (1 - fraction_to_turn))).normalized()
			var turned_h_velocity = turn_direction * h_velocity.length()
			player_velocity = Vector3(turned_h_velocity.x, player_velocity.y, turned_h_velocity.z)
		h_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
		if h_velocity.dot(direction) <= SPEED:
			player_velocity += (direction * (SPEED - h_velocity.dot(direction))) * AIR_ACCEL * delta
		player_velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("click"):
		if $ThirdPersonCamera.current:
			$Camera3D.make_current()
		else:
			$ThirdPersonCamera.make_current()
	
#	velocity = velocity.lerp(direction * SPEED, SPEED * delta)
#	move_and_slide()
	move_and_slide_custom(player_velocity * delta)
	game_tick += 1

func compute_vertical_distance_from_floor(floor_contact: Dictionary, player_position: Vector3):
	# Skin depth just to be sure we don't apply snap gravity when super close to floor
	var implied_contact_point_on_player_collider: Vector3 = player_position - (floor_contact.normal * (COLLISION_RADIUS - SKIN_DEPTH))
	var distance_from_floor_along_normal = implied_contact_point_on_player_collider.distance_to(floor_contact.position)
	return distance_from_floor_along_normal / floor_contact.normal.dot(UP)

func compute_snap_motion(floor_point, floor_normal, player_position, current_velocity):
	var implied_position_based_on_floor_contact = (floor_point + (floor_normal * COLLISION_RADIUS))
	var implied_position_offset = implied_position_based_on_floor_contact - player_position
	#if (implied_position_offset.length() > 0.01 
		#and implied_position_offset.normalized().dot(UP) < -TOLERANCE
		#and (current_velocity == Vector3.ZERO or implied_position_offset.normalized().dot(current_velocity.normalized()) < -TOLERANCE)):
		#var snap_magnitude = min(implied_position_offset.length(), 0.2) # max(0.01, 0.5 * implied_position_offset.length())
		#return implied_position_offset
	if implied_position_offset.length() > 0.01 and implied_position_offset.normalized().dot(UP) < -TOLERANCE:
		var snap_magnitude = min(implied_position_offset.length(), 0.1) # max(0.01, 0.5 * implied_position_offset.length())
		return snap_magnitude * -floor_normal
	else:
		return Vector3.ZERO

func move_and_slide_custom(motion: Vector3):
#	if game_tick < 30:
#		motion = Vector3(0.125, 0, -0.25)
#		print(vtos(global_position), " -- frame -- ", game_tick)
#		add_debug_sphere(global_position)
	var last_normal: Vector3 = Vector3.ZERO
	# I know we can just use direction but maybe will replace that with vel in future
	var original_direction = motion.normalized() 
	$CollisionShape3D.shape = collision_shape
	# resolve static collisions
	move_and_collide(Vector3(0, player_gravity, 0), false, 0.005, false, 1)
#	var ground_collision = KinematicCollision3D.new()
#	if test_move(global_transform, Vector3.DOWN * 0.1, ground_collision) and ground_collision.get_normal().angle_to(Vector3.UP) < PI / 4:
#		print("SLIDING ON GROUND")
#		motion = motion.slide(ground_collision.get_normal())
	$CollisionShape3D.shape = smaller_collision_shape
	for i in 4:
#		print("motion: ", motion)
		var location = global_position
#		print(vtos(location), " -- new" if i == 0 else "")
		var collision: KinematicCollision3D = move_and_collide(motion, false, 0.005, false, 1)
		if not collision:
			break
		# correct for skin depth
		position += collision.get_normal() * collision.get_depth()
		# compute slide motion
		var slid_motion = slid_along_crease_if_applicable(collision.get_remainder().slide(collision.get_normal()), original_direction, collision, last_normal)
		if game_tick in debug_ticks:
			print("Collision: ",  
				"\n\tstartpos: ", location, ", numcollisions: ", collision.get_collision_count(),
				"\n\tmotion: ", motion,
				"\n\tslid_motion: ", slid_motion,
				"\n\tnormal: ", collision.get_normal(), 
				"\n\tposition: ", collision.get_position(), 
				"\n\ttravel: ", collision.get_travel(),
				"\n\tdepth: ", collision.get_depth())
#		else:
#			var slide_direction_in_order = original_direction.slide(last_normal).slide(collision.get_normal()).normalized()
#			var slide_direction_reverse_order = original_direction.slide(collision.get_normal()).slide(last_normal).normalized()
#			var dot_product = slide_direction_in_order.dot(slide_direction_reverse_order)
#			if dot_product < 0.6:
#				print("Slide order dependency")
#				var crease_direction: Vector3 = last_normal.cross(collision.get_normal()).normalized()
#				slid_motion = collision.get_remainder().project(crease_direction)
		
		last_normal = collision.get_normal()
		
		if original_direction.dot(slid_motion.normalized()) < 0:
#			print("\t\tSTOPPING because slid motion opposite original")
			motion = Vector3.ZERO
#			motion = slid_motion - slid_motion.project(original_direction)
		elif original_direction.slide(collision.get_normal()).angle_to(slid_motion) >= (PI / 2) - 0.0001:
#			print("\t\tSTOPPING because original motion slid along last collision plane opposes the latest motion slide")
			motion = Vector3.ZERO
		else:
			motion = slid_motion
		if motion:
			if motion.normalized().dot(player_velocity.normalized()) > 0:
				player_velocity = player_velocity.project(motion.normalized())
			else:
				player_velocity *= 0.85
#		motion = slid_motion

func slid_along_crease_if_applicable(slid_motion: Vector3, original_direction: Vector3, collision: KinematicCollision3D, last_normal: Vector3):
	if last_normal == Vector3.ZERO:
		return slid_motion
	
	var is_slide_direction_against_last_normal = slid_motion.normalized().dot(last_normal) < -0.001
	var outwards_from_crease: Vector3 = (last_normal + collision.get_normal()).normalized()
	var original_against_last_normal = original_direction.slide(last_normal).normalized()
	var original_against_current_normal = original_direction.slide(collision.get_normal()).normalized()
	var is_original_direction_towards_crease = (
		original_against_current_normal.dot(outwards_from_crease) < 0 and original_against_last_normal.dot(outwards_from_crease) < 0)
	if is_slide_direction_against_last_normal or is_original_direction_towards_crease:
		var crease_direction: Vector3 = last_normal.cross(collision.get_normal()).normalized()
		position += 0.005 * outwards_from_crease
		return collision.get_remainder().project(crease_direction)
	else:
		return slid_motion

func normalize_angle_to_positive_degrees(angle: float):
	angle = fmod(angle, FULL_ROTATION_DEGREES)
	return angle + FULL_ROTATION_DEGREES if angle < 0 else angle

func project_vector_onto_plane_along_direction(vector, plane_normal, direction):
	var distance_to_plane_from_vector_along_direction = -1.0 * (plane_normal.dot(vector) / plane_normal.dot(direction))
	var estimated_projected_vector = vector + direction * distance_to_plane_from_vector_along_direction
	var exact_projected_vector = Plane(plane_normal, 0).project(estimated_projected_vector)
	return exact_projected_vector

# *********************************************************************
# *********************************************************************
# *********************************************************************

const SIM_TICKS = 10
const ERROR_MARGIN = 0.001
const VELOCITY_CHANGE_TICKS = 15

const VELOCITY_KEY = "velocity"
const POSITION_KEY = "transform"
const TICK_KEY = "tick"
const FLOOR_RESULT_KEY = "floor_result"
const SKIN_DEPTH = 0.001

@onready var physics_fps = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")

var tick_limit: int = 10000
var speed = 100.0
var acceleration = 1.0
var game_tick: int = 0
var state_history: Array = []
var floor_results: Dictionary = {}
var errors: Array[float] = []
var linear_velocity = Vector3.ZERO
var print_stats_interval = 1000

var debug_ticks = [] # [702, 703]
var collision_shape: SphereShape3D = SphereShape3D.new()
var smaller_collision_shape: SphereShape3D = SphereShape3D.new()

func _ready():
	collision_shape.radius = COLLISION_RADIUS
	smaller_collision_shape.radius = COLLISION_RADIUS - SKIN_DEPTH
	state_history.push_back({POSITION_KEY: global_position, VELOCITY_KEY: linear_velocity, TICK_KEY: game_tick})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func move(delta):
	move_and_slide_custom(linear_velocity * delta)
	return
#	velocity = linear_velocity
#	linear_velocity = move_and_slide()
	if abs(delta - (1.0 / physics_fps)) > 0.001:
		print("delta: ", delta)
	var last_normal: Vector3 = Vector3.ZERO
	var motion = linear_velocity * delta
#	var res = move_and_collide(motion, false, 0.005, false)
	$CollisionShape3D.shape = collision_shape
	move_and_collide(Vector3.ZERO, false, 0.005, false, 1)
	$CollisionShape3D.shape = smaller_collision_shape
	for i in 4:
		var location = global_position
		# no-op move for depenetration
#		$CollisionShape3D.shape = collision_shape
#		move_and_collide(Vector3.ZERO, false, 0.005, false, 1)
		# actual movement with smaller collider
		$CollisionShape3D.shape = smaller_collision_shape
		var collision: KinematicCollision3D = move_and_collide(motion, false, 0.005, false, 1)
		if not collision:
			break
		# correct for skin depth, doing naive for now
#		position += SKIN_DEPTH * collision.get_normal()
		var dist1 = (COLLISION_RADIUS - SKIN_DEPTH) / abs(collision.get_normal().dot(collision.get_travel().normalized()))
		var skin_correction = - (SKIN_DEPTH / (COLLISION_RADIUS - SKIN_DEPTH)) * dist1 * collision.get_travel().normalized()
		position += collision.get_normal() * collision.get_depth()
		# compute slide motion
		var slid_motion = collision.get_remainder().slide(collision.get_normal())
		if slid_motion.normalized().dot(last_normal) < -0.001:
			var crease_direction: Vector3 = last_normal.cross(collision.get_normal()).normalized()
			slid_motion = collision.get_remainder().project(crease_direction)
			position += 0.01 * (collision.get_normal() + last_normal).normalized()
		if game_tick in debug_ticks:
			print("Collision for tick ", game_tick, 
				"\n\tstartpos: ", location, ", motion: ", motion, ", numcollisions: ", collision.get_collision_count(),
				"\n\tnormal: ", collision.get_normal(), 
				"\n\tposition: ", collision.get_position(), 
				"\n\ttravel: ", collision.get_travel(),
				"\n\tdepth: ", collision.get_depth(), 
				"\n\tskin_correction: ", skin_correction)
		last_normal = collision.get_normal()
		motion = slid_motion

func _integrate_forces(state):
	pass

func run_simulation(delta):
	if game_tick % print_stats_interval == 0:
		errors.sort()
		print(errors.slice(-50))
	if game_tick == tick_limit:
		get_tree().quit()
	var state_at_frame_begin = current_state()
	var simulated_state = simulate(delta)
	var position_error = (simulated_state[POSITION_KEY] - state_at_frame_begin[POSITION_KEY]).length()
	if game_tick in debug_ticks:
		print(simulated_state[POSITION_KEY])
		print(state_at_frame_begin[POSITION_KEY])
	if position_error > ERROR_MARGIN and game_tick > 60:
		print("%d, %.5f" % [game_tick, position_error])
		errors.push_back(position_error)
	if position_error > 0.01 and game_tick > 60:
		print(state_history.slice(-SIM_TICKS))
	reset_state_to_before_simulation(state_at_frame_begin)
	state_history.push_back(state_at_frame_begin)
	floor_results[game_tick] = find_floor(global_position, -999)
	move(delta)
	game_tick += 1

func update_state(initial_state: Dictionary):
	linear_velocity = calculate_random_velocity(initial_state) # Vector3.FORWARD * 0.5 # 
	global_position = initial_state[POSITION_KEY]
	force_update_transform()

func calculate_random_velocity(state: Dictionary):
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state[TICK_KEY] / VELOCITY_CHANGE_TICKS)
	return speed * Vector3(
		rng.randf_range(-1, 1),
		rng.randf_range(-1, 1),
		rng.randf_range(-1, 1)
	)

func calculate_back_forth_velocity(state: Dictionary):
	return Vector3.FORWARD if sin(state[TICK_KEY] * physics_fps) > 0 else Vector3.BACK

func simulate(delta):
	if len(state_history) < SIM_TICKS:
		return current_state()
	var recorded_states: Array = state_history.slice(-SIM_TICKS)
	global_position = state_history[-SIM_TICKS][POSITION_KEY]
	for past_state in recorded_states:
		var sim_tick = past_state[TICK_KEY]
		var sim_state = {POSITION_KEY: global_position, VELOCITY_KEY: Vector3.ZERO, TICK_KEY: sim_tick}
		update_state(sim_state)
		validate_floor_result(sim_tick, past_state[POSITION_KEY])
		if game_tick in debug_ticks:
			print("Sim ", sim_tick, " ", global_position)
		move(delta)
	return {POSITION_KEY: global_position, VELOCITY_KEY: linear_velocity, TICK_KEY: state_history.back()[TICK_KEY]}

func validate_floor_result(sim_tick, sim_position):
	var simulated_floor_result = find_floor(sim_position, -999)
	var original_floor_result = floor_results[sim_tick]
	if abs(simulated_floor_result.normal.angle_to(original_floor_result.normal)) > ERROR_MARGIN:
		print("Simulated floor normal for tick ", sim_tick, " has different value than original",
			"\n\t original value: ", original_floor_result.normal,
			"\n\t simulate value: ", simulated_floor_result.normal)
	if (simulated_floor_result.position - original_floor_result.position).length() > ERROR_MARGIN:
		print("Simulated floor position for tick ", sim_tick, " has different value than original",
			"\n\t original value: ", original_floor_result.position,
			"\n\t simulate value: ", simulated_floor_result.position)

func current_state():
	return {POSITION_KEY: global_position, VELOCITY_KEY: linear_velocity, TICK_KEY: game_tick}

func reset_state_to_before_simulation(state_before_simulation):
	update_state(state_before_simulation)

func vtos(vector:Vector3):
	return "(%+.3f, %+.3f, %+.3f)" % [vector.x, vector.y, vector.z]

func add_debug_sphere(location):
	var sphere_instance: MeshInstance3D = debug_sphere.instantiate()
	add_child(sphere_instance)
	sphere_instance.global_position = location

# *********************************************************************
# *********************************************************************
# *********************************************************************

const UP = Vector3.UP
const DOWN = -UP 
const NOT_ON_FLOOR: Dictionary = {"normal": Vector3.ZERO, "position": Vector3.ZERO}
const FLOOR_CHECK_DIST:float = 1
const FLOOR_CHECK_TOLERANCE:float = 0.01
const FLOOR_ANGLE:float = deg_to_rad(46)
const MIN_FLOOR_CONTACT_DEPTH:float = 0.00001
func find_floor(start_pos: Vector3, floor_check_distance: float):
	# ---- Static Test @ Start ----
	var rest_contacts = get_rest_contacts(start_pos)
	var best_floor = best_floor(rest_contacts, start_pos, floor_check_distance)
#	if counter % 120 == 0:
#		cl_print(["contacts", rest_contacts, "\nbest floor", best_floor])
	if best_floor != NOT_ON_FLOOR: return best_floor
	# ---- Sweep Test ----
	var motion = cast_sphere(start_pos, DOWN * floor_check_distance)
	var end_pos = start_pos + DOWN * ((floor_check_distance * motion[1]) + FLOOR_CHECK_TOLERANCE)
	rest_contacts = get_rest_contacts(end_pos)
#	if counter % 120 == 0:
#		cl_print(["motion", motion, "\nmotion contacts", rest_contacts, "\nbest floor", best_floor])
	var motion_left_for_wall_check = (1.0 - motion[1]) * floor_check_distance
	best_floor = best_floor(rest_contacts, end_pos, motion_left_for_wall_check)
	return best_floor

func best_floor(contacts: Array, current_position, motion_left, iters=3):
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
	var hit_point = contact.position + contact.normal * FLOOR_CHECK_TOLERANCE
	var start_pos = contact.position + contact.normal * COLLISION_RADIUS
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
				var hit_pos = floor_hit.position + floor_hit.normal * COLLISION_RADIUS
#				state.transform.origin = state.transform.origin.linear_interpolate(
#					hit_pos, 0.9)
				return floor_hit
#			var base_normal = base_hit.normal
#			var contact_point = start_pos + (-base_normal * COLLISION_RADIUS)
#			# offset ray start in case contact_point is inside floor
#			var floor_hit = space_state.intersect_ray(
#				contact_point - down_wall_dir * 0.01, 
#				contact_point + down_wall_ray, [self])
#			if (floor_hit and 
#				floor_hit.normal.distance_to(base_normal) < TOLERANCE and
#				floor_hit.point.distance_to(contact_point) < motion_left):
#				return {"normal": base_normal, "point": floor_hit.position}
	return NOT_ON_FLOOR

func verify_sphere_contact(point, direction, normal, distance, radius=COLLISION_RADIUS):
	# use raycast to check if a spherecast would collide at the given normal
	var space_state = get_world_3d().direct_space_state
	var contact_point = point + (-normal * radius)
	# offset a bit in case contact_point is inside another shape
	var contact_hit = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		contact_point - direction * FLOOR_CHECK_TOLERANCE, 
		contact_point + direction * distance, 
		0xFFFFFFFF,
		[self]))
	if contact_hit and contact_hit.normal.distance_to(normal) < FLOOR_CHECK_TOLERANCE:
		return {"normal": normal, "position": contact_hit.position}
	return NOT_ON_FLOOR

func is_floor(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) <= FLOOR_ANGLE + FLOOR_CHECK_TOLERANCE

func is_ceil(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) >= PI/2 + FLOOR_CHECK_TOLERANCE

func compare_contact_flatness(a, b):
	return a.normal.dot(UP) >= b.normal.dot(UP)

func get_rest_contacts(position, shape=collision_shape):
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
		if contact_depth >= MIN_FLOOR_CONTACT_DEPTH:
			contact_vec = outer_point - inner_point
		else:
			if shape.get_class() == "SphereShape":
				contact_vec = position - inner_point
			else:
				var ray_end = position + (outer_point - position) * (1 + FLOOR_CHECK_TOLERANCE)
				var ray_query_params = PhysicsRayQueryParameters3D.create(position, ray_end, 0xFFFFFFFF, [self])
				var hit = space_state.intersect_ray(ray_query_params)
				if hit:
					contact_vec = hit.normal
				else:
					contact_vec = position - inner_point
		contacts.append({"normal": contact_vec.normalized(), "position": outer_point})
	return contacts

func collision_points(position, shape=collision_shape, margin=0):
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

func cast_sphere(position, motion, radius=COLLISION_RADIUS):
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	return cast_motion(position, motion, sphere)

class EvictingFifoQueue:
	var _size:int = 0
	var _backing_array:Array = []
	
	func _init(size: int):
		_size = size
	
	func add(element):
		if _backing_array.size() > _size:
			_backing_array.pop_front()
		_backing_array.push_back(element)
	
	func peek_front():
		if _backing_array.is_empty():
			return null
		else:
			return _backing_array.front()
	
	func pop_front():
		return _backing_array.pop_front()
	
	func elements():
		return _backing_array.duplicate()
