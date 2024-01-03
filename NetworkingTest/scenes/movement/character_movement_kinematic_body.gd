extends CharacterBody3D

class_name CharacterMovementKinematicBody

const COLLISION_RADIUS = 2.5
const COLLISION_MARGIN = 0.005
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
const SKIN_DEPTH = 0.01

const UP = Vector3.UP
const DOWN = -UP 
const FLOOR_CHECK_TOLERANCE:float = 0.01
const FLOOR_ANGLE:float = deg_to_rad(46)

@onready var debug_sphere = preload("res://scenes/debug_sphere.tscn")
@onready var camera = $Camera3D
@onready var last_position = global_position 
var yaw_: float = 0
var pitch_: float = 0
var game_tick_: int = 0
var enable_collision_logging_ = false
var collision_shape: SphereShape3D = SphereShape3D.new()
var smaller_collision_shape: SphereShape3D = SphereShape3D.new()

func compute_next_physics_state(initial_physics_state, player_input):
	yaw_ = player_input["yaw"]
	pitch_ = player_input["pitch"]
	global_position = initial_physics_state["position"]
	
	last_position = global_position
	return move(initial_physics_state, player_input)
	#return debug_move(player_input)

func move(physics_state, player_input):
	var delta = 1.0 / 60
	var player_velocity = physics_state["velocity"]
	var h_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
	var input_dir = player_input["direction"]
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(yaw_))
	var direction = (facing_horizontal_direction_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#if !physics_state["is_moving_along_floor"]:
		#cl_print(["NOT ALONG FLOOR"])
	var floor_check_distance = 1.0 if physics_state["is_moving_along_floor"] else 0.01
	var floor_check = FloorCheck.new(get_world_3d().direct_space_state, COLLISION_RADIUS, player_velocity.normalized(), [self], multiplayer.is_server())
	var floor_contact = floor_check.find_floor(global_position, floor_check_distance)
	
	var is_moving_along_floor = true
	#cl_print([vtos(floor_contact.normal)])
	if is_floor(floor_contact.normal):
		var target_velocity = project_vector_onto_plane_along_direction(direction * SPEED, floor_contact.normal, UP)
		#player_velocity = project_vector_onto_plane_along_direction(player_velocity, floor_contact.normal, UP)
		player_velocity = player_velocity.lerp(target_velocity, GROUND_ACCEL * delta)
		if player_input["is_jumping"]:
			player_velocity.y = JUMP_FORCE
			is_moving_along_floor = false
		#elif Input.is_action_pressed("slow"):
			#player_velocity.y = 2 * JUMP_FORCE
			#player_velocity += 50 * direction
			#is_moving_along_floor = false
		else:
			global_position += compute_snap_motion(floor_contact.position, floor_contact.normal, global_position, player_velocity)
	else:
		is_moving_along_floor = false
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
	
	#if Input.is_action_just_pressed("click"):
		#if $ThirdPersonCamera.current:
			#$Camera3D.make_current()
		#else:
			#$ThirdPersonCamera.make_current()
	
	player_velocity = move_and_slide_target_point(player_velocity, delta)
	#cl_print(["\tend position: ", global_position])
	return { "velocity": player_velocity, "position": global_position, "is_moving_along_floor": is_moving_along_floor }

func debug_move(player_input):
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(player_input["yaw"]))
	var horizontal_direction = (facing_horizontal_direction_basis * Vector3(player_input["direction"].x, 0, player_input["direction"].y)).normalized()
	var vertical_direction = Vector3.ZERO
	if player_input["is_jumping"]:
		vertical_direction += UP
	if player_input["is_slow_walking"]:
		vertical_direction += DOWN
	#var debug_speed = 0.0005 if Input.is_action_pressed("") else 0.01
	var player_velocity = (horizontal_direction + vertical_direction) * SPEED
	
	move_and_slide_target_point(player_velocity, 1.0 / 60)
	
	return { "velocity": Vector3.ZERO, "position": global_position }

func _ready():
	collision_shape.radius = COLLISION_RADIUS
	smaller_collision_shape.radius = COLLISION_RADIUS - SKIN_DEPTH
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if (event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		#yaw_ = normalize_angle_to_positive_degrees(yaw_ - (event.relative.x) * MOUSE_SENSITIVITY)
		#pitch_ = clamp(pitch_ - (event.relative.y * MOUSE_SENSITIVITY), -90.0, 90.0)
		pass
	elif event.is_action_pressed("toggle_mouse_mode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	var frame_lerped_position = last_position.lerp(global_position, Engine.get_physics_interpolation_fraction())
	camera.global_position = frame_lerped_position + Vector3(0, 0.75, 0)
	var current_rotation_basis = Quaternion(Basis.IDENTITY.from_euler(Vector3(deg_to_rad(pitch_), deg_to_rad(yaw_), 0)))
	camera.basis = Basis(Quaternion(camera.basis).slerp(current_rotation_basis, 0.5))
	$DebugLabels/DebugLabel0.set_text(str(delta))

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
		var snap_magnitude = min(max(TOLERANCE, implied_position_offset.length()), 0.1) # max(0.01, 0.5 * implied_position_offset.length())
		if enable_collision_logging_:
			cl_print(["snap motion: ", snap_magnitude * -floor_normal])
		return implied_position_offset * 0.99 # -floor_normal
	else:
		return Vector3.ZERO

func move_and_slide_custom(vel:Vector3, delta:float) -> Vector3:
	var motion = vel * delta
	var velocity_after_slide = vel
	var last_normal: Vector3 = Vector3.ZERO
	# I know we can just use direction but maybe will replace that with vel in future
	var original_direction = motion.normalized() 
	$CollisionShape3D.shape = collision_shape
	# resolve static collisions
	var resting_collision: KinematicCollision3D = move_and_collide(Vector3.ZERO, false, COLLISION_MARGIN, false, 1)
	$CollisionShape3D.shape = smaller_collision_shape
	for i in 4:
		if motion == Vector3.ZERO:
			break
#		print("motion: ", motion)
		var start_position = global_position
#		print(vtos(location), " -- new" if i == 0 else "")
		var collision: KinematicCollision3D = move_and_collide(motion, false, COLLISION_MARGIN, false, 10)
		if not collision:
			break
		#print("Num collisions for slide %d: %d" % [i, collision.get_collision_count()])
		# correct for skin depth
		position += collision.get_normal() * collision.get_depth()
		# compute slide motion
		var raw_slid_remainder = collision.get_remainder().slide(collision.get_normal())
		var slid_motion = slide_along_crease_if_applicable(raw_slid_remainder, original_direction, collision, last_normal)
		if true:
			cl_print(["Collision: ", i,
				"\n\tstartpos: ", start_position, ", numcollisions: ", collision.get_collision_count(),
				"\n\tmotion: ", motion,
				"\n\tslid_motion: ", slid_motion,
				"\n\tnormal: ", collision.get_normal(), 
				"\n\tposition: ", collision.get_position(), 
				"\n\ttravel: ", collision.get_travel(),
				"\n\tdepth: ", collision.get_depth()])
		
		last_normal = collision.get_normal()
		
		if original_direction.dot(slid_motion.normalized()) < 0:
			#print("\t\tSTOPPING because slid motion opposite original")
			motion = Vector3.ZERO
#			motion = slid_motion - slid_motion.project(original_direction)
		elif original_direction.slide(collision.get_normal()).angle_to(slid_motion) >= (PI / 2) - 0.0001:
			#print("\t\tSTOPPING because original motion slid along last collision plane opposes the latest motion slide")
			motion = Vector3.ZERO
		else:
			motion = slid_motion
		
		if motion:
			# TODO: should this be dot(original_direction)?
			if motion.normalized().dot(velocity_after_slide.normalized()) > 0:
				velocity_after_slide = velocity_after_slide.project(motion.normalized())
			else:
				velocity_after_slide = Vector3.ZERO
	return velocity_after_slide

func move_and_slide_target_point(vel:Vector3, delta:float) -> Vector3:
	var motion = vel * delta
	var velocity_after_slide = vel
	var last_normal: Vector3 = Vector3.ZERO
	var original_direction = motion.normalized() 
	var target_position = global_position + motion
	var position_before_move = global_position
	$CollisionShape3D.shape = collision_shape
	# resolve static collisions
	var resting_collision: KinematicCollision3D = move_and_collide(Vector3.ZERO, false, COLLISION_MARGIN, false, 1)
	$CollisionShape3D.shape = smaller_collision_shape
	for i in 4:
		if motion == Vector3.ZERO:
			break
#		print("motion: ", motion)
		var start_position = global_position
#		print(vtos(location), " -- new" if i == 0 else "")
		var collision: KinematicCollision3D = move_and_collide(motion, false, COLLISION_MARGIN, false, 10)
		if not collision:
			break
		
		#print("Num collisions for slide %d: %d" % [i, collision.get_collision_count()])
		# correct for skin depth
		position += collision.get_normal() * collision.get_depth()
		# compute slide motion
		#var remaining_travel_distance = collision.get_remainder().length()
		var direction_towards_target = (target_position - global_position).normalized()
		var next_motion_towards_target = target_position - global_position # direction_towards_target * remaining_travel_distance
		var raw_slid_motion = next_motion_towards_target.slide(collision.get_normal())
		#var raw_slid_remainder = collision.get_remainder().slide(collision.get_normal())
		var slid_motion
		if last_normal == Vector3.ZERO:
			slid_motion = raw_slid_motion
		else:
			var is_slide_direction_against_last_normal = raw_slid_motion.normalized().dot(last_normal) < -0.0001
			var outwards_from_crease: Vector3 = (last_normal + collision.get_normal()).normalized()
			var target_direction_against_last_normal = direction_towards_target.slide(last_normal).normalized()
			var target_direction_against_current_normal = direction_towards_target.slide(collision.get_normal()).normalized()
			var is_target_direction_towards_crease = (
				target_direction_against_current_normal.dot(outwards_from_crease) < 0 and
				target_direction_against_last_normal.dot(outwards_from_crease) < 0)
			if is_slide_direction_against_last_normal or is_target_direction_towards_crease:
				var crease_direction: Vector3 = last_normal.cross(collision.get_normal()).normalized()
				position += COLLISION_MARGIN * outwards_from_crease
				slid_motion = collision.get_remainder().project(crease_direction)
			else:
				slid_motion = raw_slid_motion
		#var slid_motion = slide_along_crease_if_applicable(next_motion_towards_target, original_direction, collision, last_normal)
		if enable_collision_logging_:
			cl_print(["Collision: ", i,
				"\n\tstartpos: ", start_position, ", numcollisions: ", collision.get_collision_count(),
				"\n\tmotion: ", motion,
				"\n\tslid_motion: ", slid_motion,
				"\n\tnormal: ", collision.get_normal(), 
				"\n\tposition: ", collision.get_position(), 
				"\n\ttravel: ", collision.get_travel(),
				"\n\tdepth: ", collision.get_depth()])
		
		last_normal = collision.get_normal()
		
		if original_direction.dot(slid_motion.normalized()) < 0:
			#print("\t\tSTOPPING because slid motion opposite original")
			motion = Vector3.ZERO
#			motion = slid_motion - slid_motion.project(original_direction)
		elif original_direction.slide(collision.get_normal()).angle_to(slid_motion) >= (PI / 2) - 0.0001:
			#print("\t\tSTOPPING because original motion slid along last collision plane opposes the latest motion slide")
			motion = Vector3.ZERO
		else:
			motion = slid_motion
		
		if motion:
			# TODO: should this be dot(original_direction)?
			if motion.normalized().dot(velocity_after_slide.normalized()) > 0:
				velocity_after_slide = velocity_after_slide.project(motion.normalized())
			else:
				velocity_after_slide = Vector3.ZERO
	var real_motion = global_position - position_before_move
	if enable_collision_logging_:
		cl_print(["end pos: ", global_position,
			"\n\treal motion: ", real_motion])
	return real_motion / delta

func slide_along_crease_if_applicable(slid_motion: Vector3, original_direction: Vector3, collision: KinematicCollision3D, last_normal: Vector3):
	if last_normal == Vector3.ZERO:
		return slid_motion
	
	var is_slide_direction_against_last_normal = slid_motion.normalized().dot(last_normal) < -0.0001
	var outwards_from_crease: Vector3 = (last_normal + collision.get_normal()).normalized()
	var original_against_last_normal = original_direction.slide(last_normal).normalized()
	var original_against_current_normal = original_direction.slide(collision.get_normal()).normalized()
	var is_original_direction_towards_crease = (
		original_against_current_normal.dot(outwards_from_crease) < 0 and original_against_last_normal.dot(outwards_from_crease) < 0)
	if is_slide_direction_against_last_normal or is_original_direction_towards_crease:
		var crease_direction: Vector3 = last_normal.cross(collision.get_normal()).normalized()
		position += COLLISION_MARGIN * 2 * outwards_from_crease
		return collision.get_remainder().project(crease_direction)
	else:
		return slid_motion

func add_debug_sphere(location):
	var sphere_instance: MeshInstance3D = debug_sphere.instantiate()
	add_child(sphere_instance)
	sphere_instance.global_position = location

func cl_print(items: Array):
	var print_str = "CL:"
	for item in items:
		print_str = print_str + " " + str(item)
	if !multiplayer.is_server():
		print(print_str)

func starting_physics_state() -> Dictionary:
	return { "velocity": Vector3.ZERO, "position": global_position, "is_moving_along_floor": false }

static func normalize_angle_to_positive_degrees(angle: float):
	angle = fmod(angle, FULL_ROTATION_DEGREES)
	return angle + FULL_ROTATION_DEGREES if angle < 0 else angle

static func project_vector_onto_plane_along_direction(vector, plane_normal, direction):
	var distance_to_plane_from_vector_along_direction = -1.0 * (plane_normal.dot(vector) / plane_normal.dot(direction))
	var estimated_projected_vector = vector + direction * distance_to_plane_from_vector_along_direction
	var exact_projected_vector = Plane(plane_normal, 0).project(estimated_projected_vector)
	return exact_projected_vector

static func vtos(vector:Vector3):
	return "(%+.3f, %+.3f, %+.3f)" % [vector.x, vector.y, vector.z]

static func is_floor(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) <= FLOOR_ANGLE + FLOOR_CHECK_TOLERANCE

static func is_puppet():
	return false

#func _physics_process(delta):
	#last_position = global_position
	#player_move(delta)

#func is_valid_floor(floor_contact):
	#if is_moving_along_floor:
		#return is_floor(floor_contact.normal)
	#else:
		#return is_floor(floor_contact.normal) && compute_vertical_distance_from_floor(floor_contact, global_position) < 0.05

#func player_move(delta):
	#var h_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
	#var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	#var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(yaw_))
	#var direction = (facing_horizontal_direction_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
#
	#$DebugLabels/DebugLabel0.text = "HORIZONTAL_SPEED: %f" % h_velocity.length()
	#
	#var floor_check_distance = 1.0 if is_moving_along_floor else 0.01
	#var floor_check = FloorCheck.new(get_world_3d().direct_space_state, COLLISION_RADIUS, [self])
	#var floor_contact = floor_check.find_floor(global_position, floor_check_distance)
	##print(vtos(floor_contact.normal))
	#if is_floor(floor_contact.normal):
		#var target_velocity = project_vector_onto_plane_along_direction(direction * SPEED, floor_contact.normal, UP)
		#player_velocity = player_velocity.lerp(target_velocity, GROUND_ACCEL * delta)
		#if Input.is_action_pressed("jump"):
			#player_velocity.y = JUMP_FORCE
			#is_moving_along_floor = false
		#elif Input.is_action_pressed("slow"):
			#player_velocity.y = 2 * JUMP_FORCE
			#player_velocity += 50 * direction
			#is_moving_along_floor = false
		#else:
			#is_moving_along_floor = true
			#global_position += compute_snap_motion(floor_contact.position, floor_contact.normal, global_position, player_velocity)
	#else:
		#is_moving_along_floor = false
		#var fraction_to_turn = 0.2
		#if (direction.dot(h_velocity.normalized()) > 0): # don't want to turn backwards
			#var turn_direction = h_velocity.normalized().slerp(direction, 3 * delta)
##			var direction_after_turn = ((h_velocity_length * fraction_to_turn * turn_direction) + (h_velocity * (1 - fraction_to_turn))).normalized()
			#var turned_h_velocity = turn_direction * h_velocity.length()
			#player_velocity = Vector3(turned_h_velocity.x, player_velocity.y, turned_h_velocity.z)
		#h_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
		#if h_velocity.dot(direction) <= SPEED:
			#player_velocity += (direction * (SPEED - h_velocity.dot(direction))) * AIR_ACCEL * delta
		#player_velocity.y -= GRAVITY * delta
	#
	#if Input.is_action_just_pressed("click"):
		#if $ThirdPersonCamera.current:
			#$Camera3D.make_current()
		#else:
			#$ThirdPersonCamera.make_current()
	#
	#player_velocity = move_and_slide_custom(player_velocity, delta)
	#game_tick_ += 1
