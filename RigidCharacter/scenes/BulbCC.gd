extends RigidBody

onready var SphereCast = preload("res://scenes/SphereCast.tscn")
onready var DebugSphere = preload("res://scenes/DebugSphere.tscn")
const MIN_CONTACT_DEPTH:float = 0.00001
const SHAPECAST_DISTANCE:float = 0.1
const SHAPECAST_TOLERANCE:float = 0.04
const TOLERANCE:float = 0.01
const FLOOR_ANGLE:float = deg2rad(46)
const STEP_HEIGHT:float = 0.5
const SNAP_LENGTH:float = 0.25
const FLOOR_CHECK_DIST:float = 0.25
onready var collider = $CollisionShape
onready var visual_root = $VisualRoot
onready var camera = $VisualRoot/Camera
onready var mesh = $VisualRoot/MeshInstance
onready var delta = 1.0 / Engine.iterations_per_second
onready var body_radius = collider.shape.radius
onready var test_body = $TestBody
var speed:float = 10.0
var max_speed_ratio:float = 1.5
var accel_gnd:float = 12.0
var accel_air:float = 5.0
var jump_height:float = 3.5
var jump_duration:float = 0.35
var gravity:float = (2.0 * jump_height) / (pow(jump_duration, 2))
var jump_force:float = gravity * jump_duration
var velocity:Vector3 = Vector3()
var position:Vector3
var floor_normal:Vector3 = Vector3()
var last_position = Vector3()
var UP:Vector3 = Vector3.UP
var DOWN:Vector3 = -UP

var mouse_sensitivity:float = 0.1
var yaw:float = 0.0
var pitch:float = 0.0

var query_shape := SphereShape.new()

func _ready():
#    query_shape.height = 1.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visual_root.set_as_toplevel(true)
	test_body.set_as_toplevel(true)
	test_body.global_transform.origin = Vector3(0, -200, 0)
	test()

func _unhandled_input(event):
	if (event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		yaw = fmod(yaw - event.relative.x * mouse_sensitivity, 360.0)
		if yaw < -180.0: yaw += 360.0
		elif yaw > 180.0: yaw -= 360.0
		pitch = clamp(pitch - (event.relative.y * mouse_sensitivity), -90.0, 90.0)
	elif event.is_action_pressed("toggle_mouse_mode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	visual_root.global_transform.origin = last_position.linear_interpolate(
		global_transform.origin, Engine.get_physics_interpolation_fraction()
	)
	visual_root.rotation_degrees.y = yaw
	camera.rotation_degrees.x = pitch
	mesh.rotation_degrees.y = yaw
	mesh.rotation_degrees.x = pitch
	
var simulating = false
func _physics_process(delta):
#    for i in 24:
#        simulating = true
#        PhysicsServer.simulate(1.0 / 60.0)
#        simulating = false
#	if Input.is_action_pressed("click"):
##        print("simulating")
#		simulating = true
#		for i in 24:
#			PhysicsServer.simulate(1.0 / 60.0)
#		simulating = false
	if Input.is_action_just_pressed("alt_click"):
		sleeping = false
#    print(linear_velocity)
	last_position = global_transform.origin

func test():
	pass

var print_ctr = 0
var zs = []
var sprint = 1.0
func _integrate_forces(state):
	velocity = state.linear_velocity
	position = state.transform.origin
	var direction = direction()
	var h_velocity = Vector3(velocity.x, 0, velocity.z)
	var floor_contact = find_floor(state)
#	if floor_contact: pvecs([floor_contact.normal])
#	else: print("no floor")
#    floor_normal = collide_floor(position + DOWN * 0.25)
#    pvecs([position])
	if floor_contact:
		floor_normal = floor_contact.normal
		position = state.transform.origin
		var motion = floor_contact.point + (floor_normal * body_radius) - position
		if motion.dot(UP) < -TOLERANCE:
			state.transform.origin += 0.3 * (motion.project(floor_normal) * (1 - TOLERANCE))
		var speed_ratio = h_velocity.length() / speed
		if speed_ratio > max_speed_ratio:
			velocity.x *= max_speed_ratio / speed_ratio
			velocity.z *= max_speed_ratio / speed_ratio
		# maintain horizontal velocity (x and z) on slopes
		var target_vel = Math.project_on_plane_along_dir(
			direction * speed, floor_contact.normal, UP)
		velocity = velocity.linear_interpolate(target_vel, min(accel_gnd * delta, 1.0))
		wall_slide(position, velocity, floor_normal)
		if Input.is_action_pressed("jump"):
#            print("JUMP")
			velocity.y = jump_force
	else:
#        print("air")
		if h_velocity.dot(direction) <= speed:
			velocity += direction * (speed - h_velocity.dot(direction)) * accel_air * delta
		velocity.y -= gravity * delta
	linear_velocity = velocity
#	if Input.is_action_just_pressed("click"):
#		sprint = 3.0 / sprint
#	debug_move(state)
	if true: #Input.is_action_just_pressed("alt_click"):
		var pos = state.transform.origin # + DOWN * FLOOR_CHECK_DIST
		print_ctr += 1
"""
		print("floor: ", best_floor_normal(normals))
		var motion = DOWN * FLOOR_CHECK_DIST
		var last_res = null
		for i in range(40):
			var res2 := PhysicsTestMotionResult.new()
			var hit = test_body.test_motion(pos, motion, res2, [self], 1.0)
			if last_res and (last_res.collision_normal != res2.collision_normal or last_res.collision_point != res2.collision_point):
				print("DESYNC!")
			last_res = res2
		print("CHECKING POINTS: ", len(pts))
		print(best_floor_normal(pts))
		var ri_last = {}
		for i in range(40):
			var ri = get_rest_info(pos, query_shape)
			if ri_last and (ri.normal != ri_last.normal or ri.point != ri_last.point):
				print("DESYNC!")
			ri_last = ri
		print(ri_last)
		print(cast_sphere(state.transform.origin, DOWN, 1))
		var test_sphere = SphereShape.new()
		test_sphere.radius = 0.95
		var restinf = get_rest_info(state.transform.origin, test_sphere)
		if restinf: pvecs([restinf.normal, restinf.point])
		else: print("no collide")
		var gnd = detect_floor_2(state)
		if gnd:
			pvecs(gnd)
		else:
			print("no floor")
"""

func wall_slide(position, velocity, floor_normal):
	var predicted_pos = position + (UP * TOLERANCE) + velocity.normalized() * delta
	var contacts = get_rest_contacts(predicted_pos)
	var slid_vel = velocity
	var slide_planes = []
	for contact in contacts:
		if is_floor(contact.normal): 
			continue
		if abs(velocity.slide(contact.normal).dot(UP)) > TOLERANCE:
			pass
		print(vtos(contact.normal))

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

func compare_contact_flatness(a, b):
	return a.normal.dot(UP) >= b.normal.dot(UP)

# return list of [normal, point]
func get_rest_contacts(position, shape=query_shape):
	var contacts = []
	var space_state = get_world().direct_space_state
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
				var hit = space_state.intersect_ray(position, ray_end, [self])
				if hit:
					contact_vec = hit.normal
				else:
					contact_vec = position - inner_point
		contacts.append({"normal": contact_vec.normalized(), "point": outer_point})
	return contacts

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
	var space_state = get_world().direct_space_state
	for point in [hit_point, start_pos]:
		var base_hit = space_state.intersect_ray(
			point, point + down_wall_ray, [self])
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

# use raycast to check if a spherecast would collide at the given normal
func verify_sphere_contact(
	position, direction, normal, distance=FLOOR_CHECK_DIST, radius=body_radius):
	var space_state = get_world().direct_space_state
	var contact_point = position + (-normal * radius)
	# offset a bit in case contact_point is inside another shape
	var contact_hit = space_state.intersect_ray(
		contact_point - direction * TOLERANCE, 
		contact_point + direction * distance, [self])
	if contact_hit and contact_hit.normal.distance_to(normal) < TOLERANCE:
		return {"normal": normal, "point": contact_hit.position}
	return {}

func detect_wall(state):
	# slide along obstructions, instead of pushing into them (jiggly)
	var wall_check_point = state.transform.origin + (UP * TOLERANCE) + velocity.normalized() * 0.1
	var wall_result = collide_shape(wall_check_point, SphereShape.new(), 1)
#	pvecs([position, velocity])
	if wall_result:
		var wall_normal = wall_result[0].normal
		pvecs([velocity, wall_normal])
		print("wall found")
		if should_wall_slide(velocity, wall_normal):
			print("Sliding ", OS.get_ticks_msec())
			var slide_normal = wall_normal.slide(floor_normal).normalized()
			velocity = velocity.slide(slide_normal)
	else:
		print("no wall")
#	var wall_normal:Vector3 = collide(position + h_velocity.normalized() * 0.005)
#	res = PhysicsTestMotionResult.new()
#	var sliding = false
#	if test_motion(position + UP * TOLERANCE, h_velocity.normalized() * 0.01, res):
#		var wall_normal = res.collision_normal
#		pvecs([velocity, floor_normal, wall_normal])
#		if should_wall_slide(velocity, wall_normal):
#			var slide_normal = wall_normal.slide(floor_normal).normalized()
#			velocity = velocity.slide(slide_normal)
##                velocity -= floor_normal * 0.25
#			sliding = true
#		print("hit")
#	else:
#		print("no hit")
#	print(sliding)
	return

func debug_print(state):
#	pvecs([state.transform.origin])
	zs.append(state.transform.origin.z)
#	if print_ctr % 5 == 0:
#		var res = PhysicsTestMotionResult.new()
#		if test_body.test_motion(state.transform.origin, DOWN * SNAP_LENGTH, res, [self], 0.95):
#			pvecs([res.collision_normal, res.motion])
#	if print_ctr % 15 == 0:
##		print("testing")
#		var res = PhysicsTestMotionResult.new()
#		PhysicsServer.body_test_motion(
#			test_body.get_rid(), 
#			Transform(Basis.IDENTITY, Vector3(0, 2, -2)), 
#			DOWN * SNAP_LENGTH, 
#			false, 
#			res,
#			true,
#			[self]
#		)
#		pvecs([res.collision_normal, res.collision_point])
##		test_motion(position, DOWN, res)
#		if res.collision_normal.y != 1.0:
#			pvecs([state.transform.origin, res.collision_normal, res.collision_point])
##			print(collide_shape(state.transform.origin + Vector3(0, 0.6, 0), SphereShape.new()))
##		spherecast(
##			position, 
##			DOWN, # * (SNAP_LENGTH + 0.05), 
##			body_radius # - 0.05
##		)
##		detect_floor(state)
	if print_ctr % 240 == 0:
		zs.sort()
		print(zs.slice(0, 10))
		zs = []
	print_ctr += 1

func debug_move(state):
	var debug_dir = direction() + (
		Input.get_action_strength("jump") - Input.get_action_strength("down")
	) * UP
	var debug_speed = 0.001 if Input.is_action_pressed("slow") else 0.1
	state.transform.origin += debug_dir * debug_speed * sprint

func debug_sphere(position, radius, lifetime):
	var dbs = DebugSphere.instance()
	add_child(dbs)
	dbs.mesh.radius = radius
	dbs.mesh.height = radius * 2.0
	dbs.global_transform.origin = position
	dbs.set_as_toplevel(true)
	dbs._free(lifetime)

func should_wall_slide(motion:Vector3, wall_normal:Vector3) -> bool:
	return (is_wall(wall_normal) and 
		abs(motion.slide(wall_normal).dot(UP)) > TOLERANCE # will slide vertically
		and wall_normal.dot(motion) < TOLERANCE) # motion is pushing into wall

func cast_motion(position, motion, shape):
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	shape_query.exclude = [self]
	shape_query.set_shape(shape)
	shape_query.transform.origin = position
	return space_state.cast_motion(shape_query, motion)

func cast_sphere(position, motion, radius=1):
	var sphere = SphereShape.new()
	sphere.radius = radius
	return cast_motion(position, motion, sphere)

func spherecast(position:Vector3, motion:Vector3, radius:float):
	var result = {}
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	var cast_shape := SphereShape.new()
	pvecs([position, motion])
	cast_shape.radius = radius
	cast_shape.margin = 0.0
	shape_query.exclude = [self]
	shape_query.set_shape(cast_shape)
	shape_query.transform.origin = position
	print(space_state.get_rest_info(shape_query))
	var cast_result = space_state.cast_motion(shape_query, motion)
	print(cast_result)
	if true: #cast_result[1] != 1.0:
		shape_query.transform.origin += motion * cast_result[1] #+ motion.normalized() * TOLERANCE
		result = space_state.get_rest_info(shape_query)
		print(result)
		return result

func snap_to_floor(state:PhysicsDirectBodyState):
	var result := PhysicsTestMotionResult.new()
	if test_motion(state.transform.origin, DOWN * SNAP_LENGTH, result) and is_floor(result.collision_normal):
		state.transform.origin += result.motion.project(result.collision_normal)
#		print("snapped", OS.get_ticks_msec())

func detect_down_slope(position, velocity):
	var space_state = get_world().direct_space_state
	var ray_body = DOWN * 2.0
	var result_near = space_state.intersect_ray(position, position + ray_body, [self])
	var result_far = space_state.intersect_ray(
		position + velocity * delta, position + velocity * delta + ray_body, [self]
		)
	if result_near and result_far:
		var slope_dir = (result_far.position - result_near.position).normalized()
		if slope_dir.dot(UP) < -TOLERANCE:
			return slope_dir
	return Vector3()

func snap(position):
	var result := PhysicsTestMotionResult.new()
	if test_motion(position, floor_normal * SNAP_LENGTH, result):
		return result.motion
	else:
		return Vector3()
	

func test_motion(position:Vector3, motion:Vector3, result:PhysicsTestMotionResult) -> bool:
	return PhysicsServer.body_test_motion(get_rid(), Transform(Basis.IDENTITY, position), motion, false, result)

func direction():
	var forward = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var right = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	return Vector3(right, 0, -forward).normalized().rotated(UP, deg2rad(yaw))

func raycast():
	var space_state = get_world().direct_space_state
	var ray_start = camera.global_transform.origin
	var ray_vec = -200 * camera.global_transform.basis.z
	var ray_end = ray_start + ray_vec
	var result = space_state.intersect_ray(ray_start, ray_end, [self])
	if result and is_instance_valid(result.collider):
		print("Hit ", result.collider)

func collision_points(position, shape=query_shape, margin=0):
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	shape_query.exclude = [self]
	shape_query.set_shape(shape)
	shape_query.margin = margin
	shape_query.transform.origin = position
	return space_state.collide_shape(shape_query)

func get_rest_info(position:Vector3, shape:Shape=query_shape):
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	shape_query.exclude = [self]
	shape_query.set_shape(shape)
	shape_query.transform.origin = position
	return space_state.get_rest_info(shape_query)

func collide_shape(position:Vector3, shape:Shape=query_shape, iters:int=1):
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	shape_query.exclude = [self]
	shape_query.set_shape(shape)
	shape_query.transform.origin = position
	var results = []
	var normal = Vector3()
	for i in iters:
		var result = space_state.get_rest_info(shape_query)
		if result: 
			results.push_back(result)
			shape_query.exclude = shape_query.exclude + [result.rid]
	return results

# position of player
func collide_head(position:Vector3) -> Vector3:
	var results = collide_shape(position + Vector3(0, 0.5, 0), query_shape, 1)
	return results[0].normal if results else Vector3()

func collide_feet(position:Vector3) -> Vector3:
	var results = collide_shape(position - Vector3(0, 0.5 - SHAPECAST_TOLERANCE, 0), query_shape, 1)
	return results[0].normal if results else Vector3()

# using near full-height collider for cases where the wall is at head height
# tradeoff: leads to some jitter when pushing into two sloped ceiling walls
# if that's more important, use a shorter collider @ feet
func collide(position:Vector3) -> Vector3:
	var shape = CylinderShape.new()
	shape.height = 2.6 # $CollisionShape.shape.height # - TOLERANCE
	var results = collide_shape(position, shape, 1)
	return results[0].normal if results else Vector3()

func collide_floor(position:Vector3) -> Vector3:
	var results = collide_shape(position - Vector3(0, 0.3, 0), query_shape, 4)
	var floor_normal = Vector3()
	for result in results:
		if is_floor(result.normal):
			floor_normal += result.normal
	return floor_normal.normalized()

func collide_lower(position:Vector3) -> Vector3:
	var results = collide_shape(position - Vector3(0, 0.5, 0), query_shape, 4)
	var normal = Vector3()
	for result in results:
		if not is_floor(result.normal) and result.normal.dot(UP) > -TOLERANCE:
			normal += result.normal
	return normal.normalized()

func collide_upper(position:Vector3) -> Vector3:
	var results = collide_shape(position, query_shape, 4)
	var upper_normal = Vector3()
	for result in results:
		if not is_floor(result.normal):
			upper_normal += result.normal
	return upper_normal.normalized()

func vsum(vectors:Array) -> Vector3:
	var sum := Vector3()
	for vector in vectors: sum += vector
	return sum

func vtos(vector:Vector3):
	return "(%+.3f, %+.3f, %+.3f)" % [vector.x, vector.y, vector.z]

func is_floor(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) <= FLOOR_ANGLE + TOLERANCE

func is_ceil(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) >= PI/2 + TOLERANCE

func is_wall(normal:Vector3) -> bool:
	return (normal) and (not is_floor(normal)) and (not is_ceil(normal))

func pvecs(vecs):
	if not vecs:
		return
	var vec_str = ""
	for vec in vecs:
		vec_str += vtos(vec) + " - "
	print(vec_str)

func phvel():
	var h_vel = Vector3(velocity.x, 0, velocity.z)
	print("%.2f" % h_vel.length())

func test_get_rest_contacts_equivalent_to_get_rest_info(position):
	var collisions = collide_shape(position, query_shape, 4)
	var normals = []
	for c in collisions:
		normals.append(c.normal)
	normals.sort()
	
	var static_res = get_rest_contacts(position, query_shape)
	var normals_2 = []
	for contact in static_res:
		normals_2.append(contact.normal)
	normals_2.sort()
	
	var n_match = true
	if len(normals) == len(normals_2):
		for i in range(len(normals)):
			n_match = n_match and (normals[i].distance_to(normals_2[i]) < TOLERANCE)
	else:
		n_match = false
	if not n_match:
		print("normals don't match")
		pvecs(normals)
		pvecs(normals_2)
		pvecs(collision_points(position, query_shape))

# deprec
func intersected_normals(position, shape):
	# raycasts toward all points the shape is intersecting
	# useful for finding floor normal when stuck in corners
	# not reliable on ledges
	var space_state = get_world().direct_space_state
	var points = collision_points(position, shape)
	pvecs(points)
	var hit_normals = []
	for point in points:
		var ray_end = position + (point - position) * (1 + TOLERANCE)
		var hit = space_state.intersect_ray(position, ray_end, [self])
		if hit: hit_normals.append(hit.normal)
	# deduplicate normals
	var unique = []
	hit_normals.sort()
	for n in hit_normals:
		if (not unique) or (unique.back().distance_to(n) > TOLERANCE):
			unique.append(n)
	return unique

# deprec
func best_floor_mixed_metric(contacts, position, motion_left=FLOOR_CHECK_DIST, iters=3):
	if not contacts: return {}
	contacts.sort_custom(self, "compare_contact_flatness")
	var best_contact = contacts[0]
	# find the 'best' floor (both close and flat), if it exists ----
	for contact in contacts:
		if not is_floor(contact.normal): break
		# only prefer flatter floor if it's closer
		var flatness_loss = best_contact.normal.dot(UP) - contact.normal.dot(UP)
		var curr_distance = contact.point.distance_to(position)
		var best_distance = best_contact.point.distance_to(position)
		if curr_distance < best_distance - (flatness_loss * 0.1):
			print("preferred")
			print(best_contact)
			print(contact)
			best_contact = contact
#	if is_floor(best_contact.normal): return best_contact
#	# reach here -> contacts are all walls or ceilings
#	for i in range(min(iters, len(contacts))):
#		if is_ceil(contacts[i].point): return {}
#		else: # wall
#			var wall_result = find_wall_floor(contacts[i], motion_left)
#			if wall_result and is_floor(wall_result.normal):
#				return wall_result
	return {}

func detect_floor_2(state):
	var test_sphere = SphereShape.new()
	var rest_iters = 3
	var rest_pos = state.transform.origin
	for i in range(rest_iters):
		var rest_info = get_rest_info(rest_pos, test_sphere)
		if not rest_info:
			print("no intersect at iter: ", i)
			break
		var rest_norm = rest_info.normal
		if is_ceil(rest_norm):
			print("intersect ceil: ", rest_norm)
			if i == rest_iters - 1:
				pass # call failsafes
			else:
				rest_pos = rest_info.point + rest_norm * (body_radius + TOLERANCE)
		elif is_floor(rest_norm):
			print("rest detect gnd")
			return [rest_norm, rest_info.point]
		else:
			pass # call wall floor routine
	# if reached this point, then rest_pos is safe to cast from (no intersect)
	var floor_normal := Vector3()
	var sweep_result := PhysicsTestMotionResult.new()
	var sweep_start = rest_pos
	var motion = DOWN * FLOOR_CHECK_DIST
	test_sphere.radius = 0.95
#	print("failsafe 1: ", get_rest_info(state.transform.origin + motion, test_sphere))
	var sweep_iters = 3
	for i in range(sweep_iters):
		var hit = test_body.test_motion(sweep_start, motion, sweep_result, [self], 0.99)
		if not hit:
			return []
		var sweep_normal = sweep_result.collision_normal
		var sweep_end = sweep_result.collision_point + sweep_normal * body_radius
#		pvecs([sweep_normal, sweep_end])
		# sweep hit ceiling -> stuck, so redo sweep from depenetrated position
		if is_ceil(sweep_normal):
			print("ceil")
			pvecs([state.transform.origin, sweep_normal, sweep_end])
			sweep_start = sweep_end + DOWN * 0.05
#			debug_sphere(sweep_start, 1, 100)
			continue
		elif is_floor(sweep_normal):
			return [sweep_normal, sweep_result.collision_point]
		else:
			var wall_result = find_wall_floor(
				sweep_result.collision_point, sweep_normal, state)
			if wall_result:
				pvecs(wall_result)
				return wall_result
	return []

func most_upward_normal(normals):
	var best = Vector3()
	for n in normals:
		if n.dot(UP) > best.dot(UP): best = n
	return best

func detect_floor(state):
	var floor_normal := Vector3()
	var sweep_result := PhysicsTestMotionResult.new()
	var sweep_start = state.transform.origin
	var motion = DOWN * FLOOR_CHECK_DIST
	var sweep_iters = 2
	for i in range(sweep_iters):
		var hit = test_body.test_motion(sweep_start, motion, sweep_result, [self], 0.99)
		if not hit:
			return []
		var sweep_normal = sweep_result.collision_normal
		var sweep_end = sweep_result.collision_point + sweep_normal * body_radius
#		pvecs([sweep_normal, sweep_end])
		# sweep hit ceiling -> stuck, so redo sweep from depenetrated position
		if sweep_normal.angle_to(DOWN) < PI/2 - TOLERANCE:
			print("ceil")
			pvecs([state.transform.origin, sweep_normal, sweep_end])
			sweep_start = sweep_end + DOWN * 0.05
			debug_sphere(sweep_start, 1, 100)
			continue
		elif is_floor(sweep_normal):
			return [sweep_normal, sweep_result.collision_point]
		else:
			# offset along normal to avoid raycast hitting wall
			var hit_point = sweep_result.collision_point + sweep_normal * TOLERANCE
			var down_wall_dir = Plane(sweep_normal, 0).project(DOWN).normalized()
			var down_wall_ray = down_wall_dir * 10
			var space_state = get_world().direct_space_state
			var wall_ray_result = space_state.intersect_ray(
				hit_point, hit_point + down_wall_ray, [self]
			)
#			pvecs([hit_point, down_wall_dir])
#			print(wall_ray_result)
			if wall_ray_result and is_floor(wall_ray_result.normal):
				floor_normal = wall_ray_result.normal
				# snap to floor
				var contact_point = sweep_end + (body_radius * -floor_normal) - down_wall_dir * 0.1
				var floor_result = space_state.intersect_ray(
					contact_point, contact_point + down_wall_ray, [self]
				)
#				pvecs([sweep_end, contact_point, floor_normal, floor_result.normal])
				if floor_result and floor_result.normal.is_equal_approx(floor_normal):
					return [floor_normal, floor_result.position]
			break
	return []

func best_floor_normal(normals):
	# if using sphere, this is equivalent to sorting by closeness to center
	# flatter ground -> closer to center of sphere (in 'xz' plane)
	var best = Vector3()
	for n in normals:
		if is_floor(n) and (n.dot(UP) > best.dot(UP)):
			best = n
	return best

func find_floor_last_resort(start_pos):
	var space_state = get_world().direct_space_state
	var hit = space_state.intersect_ray(
		start_pos, start_pos + DOWN * (body_radius + 4 * FLOOR_CHECK_DIST), [self])
	if hit and is_floor(hit.normal):
		var final_contact = verify_sphere_contact(
			start_pos, DOWN, hit.normal, FLOOR_CHECK_DIST)
		if final_contact: 
			return final_contact
	return {}

