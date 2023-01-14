extends RigidBody

onready var SphereCast = preload("res://scenes/SphereCast.tscn")
onready var DebugSphere = preload("res://scenes/DebugSphere.tscn")
const SHAPECAST_DISTANCE:float = 0.1
const SHAPECAST_TOLERANCE:float = 0.04
const TOLERANCE:float = 0.01
const FLOOR_ANGLE:float = deg2rad(46)
const STEP_HEIGHT:float = 0.5
const SNAP_LENGTH:float = 0.25
const GROUND_CHECK_DIST:float = 0.25
onready var collider = $CollisionShape
onready var visual_root = $VisualRoot
onready var camera = $VisualRoot/Camera
onready var mesh = $VisualRoot/MeshInstance
onready var delta = 1.0 / Engine.iterations_per_second
onready var collider_radius = collider.shape.radius
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
	
"""
NOTE: 0.25 is used everywhere, but nothing special about it, tune if needed

down_dist = how far you can cast_motion down
[makes floor check more precise on stairs/ledges]

if down_dist < FLOOR_CHECK_DIST:
	do floor check @ down_dist + TOLERANCE

if floor below:
	snap to floor
	friction / speed limit
	lerp velocity towards input direction
	for i in 2: # in case wall immediately after step up/down (may be too edgy of an edge case)
		check if walking into wall
		if wall:
			if stair step:
				step up
			else:
				wall slide
	do jump
else:
	air strafing
	gravity

"""
# TODO: wall sliding in flat corner...seems like velocity has a downwards y component, always .25
# regardless of the wall slide down force (unless it's 0)
# lowering the wall check distance seems to work...
var print_ctr = 0
var zs = []
func _integrate_forces(state):
	velocity = linear_velocity
	position = state.transform.origin
#    pvecs([position])
	var direction = direction()
	var h_velocity = Vector3(velocity.x, 0, velocity.z)
	var res := PhysicsTestMotionResult.new()
	test_motion(position, Vector3.DOWN * SNAP_LENGTH, res)
	floor_normal = res.collision_normal
#    floor_normal = collide_floor(position + Vector3.DOWN * 0.25)
#    pvecs([position])
	if floor_normal and is_floor(floor_normal):
#        print("floor")
#        snap_to_floor(state)
		position = state.transform.origin
		var speed_ratio = h_velocity.length() / speed
		if speed_ratio > max_speed_ratio:
			velocity.x *= max_speed_ratio / speed_ratio
			velocity.z *= max_speed_ratio / speed_ratio
		# maintain horizontal velocity (x and z) on slopes
		var target_vel = Math.get_slope_velocity(direction * speed, floor_normal)
		velocity = velocity.linear_interpolate(target_vel, clamp(accel_gnd * delta, 0.0, 1.0))
#		detect_wall(state)
		if Input.is_action_pressed("jump"):
#            print("JUMP")
			velocity.y = jump_force
	else:
#        print("air")
		if h_velocity.dot(direction) <= speed:
			velocity += direction * (speed - h_velocity.dot(direction)) * accel_air * delta
		velocity.y -= gravity * delta
	linear_velocity = velocity
#	debug_move(state)
	if Input.is_action_pressed("alt_click"):
		print(state.transform.origin)
		var gnd = detect_ground(state)
		if gnd:
			pvecs(gnd)
#			var dbs = DebugSphere.instance()
#			add_child(dbs)
#			dbs.set_as_toplevel(true)
#			dbs.mesh.height = 0.1
#			dbs.mesh.radius = 0.05
#			dbs.global_transform.origin = gnd[1]
		else:
			print("no ground")
#	print_ctr += 1
	debug_print(state)


func detect_ground(state):
	var ground_normal := Vector3()
	var sweep_result := PhysicsTestMotionResult.new()
	var sweep_start = state.transform.origin
	var motion = Vector3.DOWN * GROUND_CHECK_DIST
	var sweep_iters = 2
	for i in range(sweep_iters):
		var hit = test_body.test_motion(sweep_start, motion, sweep_result, [self], 0.95)
		if not hit:
			return []
		var sweep_normal = sweep_result.collision_normal
		var sweep_end = sweep_result.collision_point + sweep_normal * collider_radius
		# sweep hit ceiling -> stuck, so redo sweep from depenetrated position
		if sweep_normal.angle_to(Vector3.DOWN) < PI/2 - TOLERANCE:
			sweep_start = sweep_end
			continue
		elif is_floor(sweep_normal):
			return [sweep_normal, sweep_result.collision_point]
		else:
			# offset along normal to avoid raycast hitting wall
			var hit_point = sweep_result.collision_point + sweep_normal * TOLERANCE
			var down_wall_dir = Plane(sweep_normal, 0).project(Vector3.DOWN).normalized()
			var down_wall_ray = down_wall_dir * 10
			var space_state = get_world().direct_space_state
			var wall_ray_result = space_state.intersect_ray(
				hit_point, hit_point + down_wall_ray, [self]
			)
			if wall_ray_result and is_floor(wall_ray_result.normal):
				ground_normal = wall_ray_result.normal
				# snap to ground
				var contact_point = sweep_end + (collider_radius * -ground_normal) - down_wall_dir * TOLERANCE
				var ground_result = space_state.intersect_ray(
					contact_point, contact_point + down_wall_ray, [self]
				)
				pvecs([sweep_end, contact_point, ground_normal, ground_result.normal])
				if ground_result and ground_result.normal.is_equal_approx(ground_normal):
					return [ground_normal, ground_result.position]
#					print("snap to ground")
#					pvecs([state.transform.origin, contact_point])
#					state.transform.origin += sweep_result.motion
#					state.transform.origin += ground_contact_result.position - contact_point
#					pvecs([state.transform.origin, sweep_result.motion, ground_contact_result.position - contact_point])

func detect_wall(state):
	# slide along obstructions, instead of pushing into them (jiggly)
	var wall_check_point = position + (Vector3.UP * TOLERANCE) + velocity.normalized() * 0.1
	var wall_result = collide_shape(wall_check_point, SphereShape.new(), 1)
	pvecs([position, velocity])
	if wall_result:
		var wall_normal = wall_result[0].normal
		pvecs([velocity, wall_normal])
		print("wall found")
		if should_wall_slide(velocity, wall_normal):
#                print("Sliding ", OS.get_ticks_msec())
			var slide_normal = wall_normal.slide(floor_normal).normalized()
			velocity = velocity.slide(slide_normal)
	else:
		print("no wall")
#	var wall_normal:Vector3 = collide(position + h_velocity.normalized() * 0.005)
#	res = PhysicsTestMotionResult.new()
#	var sliding = false
#	if test_motion(position + Vector3.UP * TOLERANCE, h_velocity.normalized() * 0.01, res):
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
#		if test_body.test_motion(state.transform.origin, Vector3.DOWN * SNAP_LENGTH, res, [self], 0.95):
#			pvecs([res.collision_normal, res.motion])
#	if print_ctr % 15 == 0:
##		print("testing")
#		var res = PhysicsTestMotionResult.new()
#		PhysicsServer.body_test_motion(
#			test_body.get_rid(), 
#			Transform(Basis.IDENTITY, Vector3(0, 2, -2)), 
#			Vector3.DOWN * SNAP_LENGTH, 
#			false, 
#			res,
#			true,
#			[self]
#		)
#		pvecs([res.collision_normal, res.collision_point])
##		test_motion(position, Vector3.DOWN, res)
#		if res.collision_normal.y != 1.0:
#			pvecs([state.transform.origin, res.collision_normal, res.collision_point])
##			print(collide_shape(state.transform.origin + Vector3(0, 0.6, 0), SphereShape.new()))
##		spherecast(
##			position, 
##			Vector3.DOWN, # * (SNAP_LENGTH + 0.05), 
##			collider_radius # - 0.05
##		)
##		detect_ground(state)
	if print_ctr % 240 == 0:
		zs.sort()
		print(zs.slice(0, 10))
		zs = []
	print_ctr += 1

func debug_move(state):
	var debug_dir = direction() + (
		Input.get_action_strength("jump") - Input.get_action_strength("down")
	) * Vector3.UP
	var debug_speed = 0.001 if Input.is_action_pressed("slow") else 0.1
	state.transform.origin += debug_dir * debug_speed



func should_wall_slide(motion:Vector3, wall_normal:Vector3) -> bool:
	return (
		not is_floor(wall_normal) 
		and abs(motion.slide(wall_normal).dot(Vector3.UP)) > TOLERANCE # will slide vertically
		and wall_normal.dot(Vector3.UP) > -0.25 # isn't a ceiling
		and wall_normal.dot(motion) < TOLERANCE # motion is pushing into wall
	)

func cast_motion(position, motion):
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	shape_query.exclude = [self]
	shape_query.set_shape(query_shape)
	shape_query.transform.origin = position + Vector3(0, -0.5, 0)
	return space_state.cast_motion(shape_query, motion)

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
	if test_motion(state.transform.origin, Vector3.DOWN * SNAP_LENGTH, result) and is_floor(result.collision_normal):
		state.transform.origin += result.motion.project(result.collision_normal)
#		print("snapped", OS.get_ticks_msec())

func detect_down_slope(position, velocity):
	var space_state = get_world().direct_space_state
	var ray_body = Vector3.DOWN * 2.0
	var result_near = space_state.intersect_ray(position, position + ray_body, [self])
	var result_far = space_state.intersect_ray(
		position + velocity * delta, position + velocity * delta + ray_body, [self]
		)
	if result_near and result_far:
		var slope_dir = (result_far.position - result_near.position).normalized()
		if slope_dir.dot(Vector3.UP) < -TOLERANCE:
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
	return Vector3(right, 0, -forward).normalized().rotated(Vector3.UP, deg2rad(yaw))

func raycast():
	var space_state = get_world().direct_space_state
	var ray_start = camera.global_transform.origin
	var ray_vec = -200 * camera.global_transform.basis.z
	var ray_end = ray_start + ray_vec
	var result = space_state.intersect_ray(ray_start, ray_end, [self])
	if result and is_instance_valid(result.collider):
		print("Hit ", result.collider)


# TODO exclude specific collision shapes, not whole colliders
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
		if not is_floor(result.normal) and result.normal.dot(Vector3.UP) > -TOLERANCE:
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
	return (normal) and normal.angle_to(Vector3.UP) <= FLOOR_ANGLE + TOLERANCE

func is_wall(normal:Vector3) -> bool:
	if is_floor(normal): 
		return false
	return (normal) and normal.angle_to(Vector3.UP) <= FLOOR_ANGLE + TOLERANCE

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

"""
func detect_ground(state):
#    print("begin")
#    pvecs([state.transform.origin, velocity])
	var sweep_result := PhysicsTestMotionResult.new()
	var ground_normal := Vector3()
	var motion = Vector3.DOWN * GROUND_CHECK_DIST
	if test_motion(state.transform.origin, motion, sweep_result):
		var sweep_normal = sweep_result.collision_normal
#        print("normal and collision point")
#        pvecs([sweep_normal, sweep_result.collision_point])
		if is_floor(sweep_normal):
#            print("hit_floor")
			ground_normal = sweep_normal
			# sweep motion is sometimes upwards when you clip into a wall, so we don't snap
			if sweep_result.motion.dot(motion) > 0: 
#                pvecs([state.transform.origin, sweep_normal, sweep_result.collision_point, sweep_result.motion])
				state.transform.origin += sweep_result.motion.project(ground_normal)
#                print(sweep_result.motion.project(ground_normal))
#            elif sweep_result.motion.dot(motion) < -TOLERANCE:
#                state.transform.origin += sweep_result.motion
#            pvecs([state.transform.origin, sweep_result.motion])
		else:
#            print("hit wall")
			# offset along normal to avoid raycast hitting wall
			var hit_point = sweep_result.collision_point + sweep_normal * TOLERANCE
			var down_wall_dir = Plane(sweep_normal, 0).project(Vector3.DOWN).normalized()
			# HARDCODED
			var target_y = state.transform.origin.y - collider_radius - GROUND_CHECK_DIST
			var down_wall_ray = down_wall_dir * (target_y - hit_point.y) / down_wall_dir.y
			var space_state = get_world().direct_space_state
			var wall_ray_result = space_state.intersect_ray(
				hit_point, hit_point + down_wall_ray, [self]
			)
			if wall_ray_result:
#                print("wall ray")
#                pvecs([floor_normal, wall_ray_result.normal, wall_ray_result.position])
				if is_floor(wall_ray_result.normal):
#                    print("hit floor at base of wall")
					ground_normal = wall_ray_result.normal
					# snap to ground
					var sweep_end = state.transform.origin + sweep_result.motion
					var contact_point = sweep_end + (collider_radius * -ground_normal) 
					var ground_contact_result = space_state.intersect_ray(
						contact_point, contact_point + down_wall_ray, [self]
					)
#                    if ground_contact_result and is_floor(ground_contact_result.normal):
#                        print("snap to ground")
#                        pvecs([state.transform.origin, contact_point])
#                        state.transform.origin += sweep_result.motion
#                        state.transform.origin += ground_contact_result.position - contact_point
#                        pvecs([state.transform.origin, sweep_result.motion, ground_contact_result.position - contact_point])
#    else:
#        print("nothing hit")
			
"""
