extends KinematicBody

# ------------------------------------------------------------------Helper Nodes
onready var client = get_node("/root/Client")
onready var camera_origin = $CameraOrigin
onready var camera = $CameraOrigin/Camera
onready var flashlight = $CameraOrigin/Camera/Flashlight
onready var weapon = $CameraOrigin/Camera/Weapon
onready var ui_ammo_reserves = $UI/Stats/Bars/Ammo/AmmoLabel/Background/Reserves
onready var ui_ammo_gauge = $UI/Stats/Bars/Ammo/AmmoGauge
onready var ui_health_label = $UI/Stats/Bars/Health/HealthLabel/Background/Number
onready var ui_health_gauge = $UI/Stats/Bars/Health/HealthGauge
onready var ui_dealt_damage_label = $UI/Stats/Bars2/DealtDamageLabel
onready var motion_time_queue = $MotionTimeQueue

var periodic_timer = Timer.new()
var periodic_timer_period = 0.1
var interpolator = Tween.new()
var animation_helper = preload("res://common/utils/AnimationHelper.gd")

# -----------------------------------------------------------------------UI Vars
var ui_meg_damage_color = Color.turquoise
var ui_big_damage_color = Color.purple
var ui_mid_damage_color = Color.salmon
var ui_lil_damage_color = Color.gray

# ---------------------------------------------------------------------Game Vars
var health = 100

# -----------------------------------------------------------------Movement Vars
enum DIRECTION {NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}
var speed = 5
var acceleration = 6
var acceleration_air = 2
var air_control = 0.3
var gravity = 0.8
var jump_cap = 1
var jump_tick_limit = 40
var wall_climb_speed = 1.5
var wall_climb_tick_limit = 50
var velocity = Vector3()
var direction = Vector3()
var ticks_since_grounded = 0
var ticks_since_walled = 0
var ticks_spent_wall_climbing = 0
var jumps_left = 0
var up_dir = Vector3()
var sprinting = false

var delta_position : Vector3 = Vector3()
var last_position : Vector3 = Vector3()
var last_queue_add_timestamp = 0
var tick_length
var phys_counter = 0
var physics_tick_length = 1.0 / Engine.iterations_per_second


# --------------------------------------------------------------------Input Vars
export var mouse_sensitivity = 0.05
var cumulative_rot_x = 0
var cumulative_rot_y = 0
var fire_mode = 0

#var phys_start_time_us = -1
#var start_pos

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	add_child(periodic_timer)
	periodic_timer.connect("timeout", self, "_periodic")
	periodic_timer.start(periodic_timer_period)
	
	print(physics_tick_length)
	motion_time_queue.init_time_queue(physics_tick_length, int(4 / physics_tick_length))
	
	add_child(interpolator)
	
	weapon.connect("clip_changed", self, "display_ammo_reserves")
	weapon.connect("recoil", self, "dash")
	weapon.connect("reload_started", self, "display_reload_progress")
	weapon.connect("dealt_damage", self, "display_damage_dealt")
	weapon.ignored_objects.append(self)

var last_period_position = Vector3()
var error_avg = 0
var new_error_weight = 0.1
func _periodic():
#	display_health()
	var real_dist_moved = get_global_transform().origin - last_period_position
	var error = real_dist_moved - get_motion_since(periodic_timer_period * 1000000)
#	print(get_motion_since(periodic_timer_period * 1000000))
#	print(real_dist_moved)
	if real_dist_moved.length() > 0:
		var pcnt_error = 100 * error.length() / real_dist_moved.length()
		#print(pcnt_error)
		if error_avg == 0:
			print("first_error")
			error_avg = pcnt_error
		else:
			error_avg = (error_avg + (new_error_weight * pcnt_error)) / (1 + new_error_weight)
#	print("%" + str(error_avg) + " error")
	last_period_position = get_global_transform().origin
#	print(phys_tick_avg)

# ----------------------------------------------------------------------Movement
var dash_ticks_dict = {}
var max_phys_tick_length = -100
var min_phys_tick_length = 100
var phys_tick_avg = 0
# leftover velocity from last frame, which is built upon 
# next frame by dashes, gravity, etc
var last_frame_final_velocity : Vector3 
func _physics_process(delta):
	update_and_add_delta_p()
	
	var accel_to_use = acceleration
	if is_on_floor():
		up_dir = get_floor_normal()
	else:
		up_dir = Vector3.UP
		if not is_on_wall():
			accel_to_use = acceleration_air
	
	velocity = velocity.linear_interpolate(
		direction * (speed + air_control * velocity.length()),
		accel_to_use * delta)
	
	#collect_inputs()
	
	
	if is_on_wall():
		ticks_since_walled = 0
	else:
		ticks_since_walled += 1
	if ticks_since_walled < 5:
		if ticks_spent_wall_climbing < wall_climb_tick_limit:
			velocity.y += wall_climb_speed
			ticks_spent_wall_climbing += 1
	velocity -= gravity * up_dir
	
	for dash_vector in dash_ticks_dict:
		var ticks_left = dash_ticks_dict[dash_vector]
		if ticks_left > 0:
			velocity += dash_vector
			dash_ticks_dict[dash_vector] -= 1
		else:
			dash_ticks_dict.erase(dash_vector)
	
#	last_queue_add_timestamp = OS.get_ticks_usec()
#	motion_time_queue.add_to_queue(velocity * delta)
	
	velocity = move_and_slide(
		velocity,
		Vector3.UP,
		true)
	
	last_frame_final_velocity = velocity
	
	if is_on_floor():
		ticks_since_grounded = 0
		ticks_spent_wall_climbing = 0
		jumps_left = jump_cap
	else:
		ticks_since_grounded += 1

func get_velocity_at_end_of_physics_frame() -> Vector3:
	var projected_velocity = last_frame_final_velocity
	var accel_to_use
	if is_on_floor():
		accel_to_use = acceleration
	else:
		accel_to_use = acceleration_air
	
	projected_velocity = projected_velocity.linear_interpolate(
		direction * (speed + air_control * velocity.length()),
		accel_to_use * physics_tick_length)
	
	if ticks_since_walled < 4:
		if ticks_spent_wall_climbing < wall_climb_tick_limit:
			projected_velocity.y += wall_climb_speed
	projected_velocity -= gravity * up_dir
	
	for dash_vector in dash_ticks_dict:
		velocity += dash_vector
	
	return projected_velocity

func jump():
	dash(Vector3(0, 1, 0), gravity * 3, 12)
	jumps_left -= 1

func dash(direction: Vector3, speed: float, ticks: int):
	dash_ticks_dict[direction * speed] = ticks

# -------------------------------------------------------------------------Input
func call_and_return(method_name: String, args):
	callv(method_name, args)
	return [method_name, args]

func set_camera_rotation(x_total_rot, y_total_rot):
	var camera_origin_rot_basis = Basis() # reset rotation
	var camera_rot_basis = Basis()
	camera_rot_basis = camera_rot_basis.rotated(Vector3(1, 0, 0), deg2rad(y_total_rot)) # then rotate around X axis
	camera_origin_rot_basis = camera_origin_rot_basis.rotated(Vector3(0, 1, 0), deg2rad(x_total_rot)) # then rotate around Y axis
	camera_origin.transform.basis = camera_origin_rot_basis
	camera.transform.basis = camera_rot_basis

func toggle_mouse_mode():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func teleport():
	transform.origin = Vector3(0, 15, 0)

func toggle_flashlight():
	if flashlight.is_visible_in_tree():
		flashlight.hide()
	else:
		flashlight.show()

func primary_action(fire_parameters):
	weapon.fire(0, fire_parameters)

func secondary_action(fire_parameters):
	weapon.fire(1, fire_parameters)

func tertiary_action(fire_parameters):
	weapon.fire(2, fire_parameters)

func set_movement():
	pass

func handle_query_input(event: InputEvent):
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cumulative_rot_x -= event.relative.x * mouse_sensitivity
		cumulative_rot_y = clamp(
			cumulative_rot_y - (event.relative.y * mouse_sensitivity),
			-90,
			90)
		return call_and_return("set_camera_rotation", [cumulative_rot_x, cumulative_rot_y])
	
	elif event.is_action_pressed("toggle_mouse_mode"):
		toggle_mouse_mode()
		return []
	
	elif event.is_action_pressed("teleport"):
		return call_and_return("teleport", [])
	
	elif (event.is_action_pressed("jump") and 
		jumps_left > 0 and 
		ticks_since_grounded < jump_tick_limit):
		return call_and_return("jump", [])
	
	elif event.is_action_pressed("toggle_flashlight"):
		return call_and_return("toggle_flashlight", [])
	
	elif event.is_action_pressed("primary_action"):
		return call_and_return("primary_action", [[camera.get_global_transform()]])
	
	elif event.is_action_pressed("secondary_action"):
		return call_and_return("secondary_action", [[camera.get_global_transform()]])
	
	elif event.is_action_pressed("tertiary_action"):
		return call_and_return("tertiary_action", [[camera.get_global_transform()]])

func handle_poll_input():
	var camera_origin_basis = camera_origin.get_global_transform().basis
	
	direction = Vector3()
	
	if Input.is_action_pressed("move_forwards"):
		direction -= camera_origin_basis.z
	elif Input.is_action_pressed("move_backwards"):
		direction += camera_origin_basis.z
	
	if Input.is_action_pressed("move_left"):
		direction -= camera_origin_basis.x
	elif Input.is_action_pressed("move_right"):
		direction += camera_origin_basis.x
	
	if Input.is_action_pressed("sprint"):
		sprinting = true
	else:
		sprinting = false
	
	
	direction = direction.normalized()
"""

func _input(event):
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cumulative_rot_x -= event.relative.x * mouse_sensitivity
		cumulative_rot_y = clamp(
			cumulative_rot_y - (event.relative.y * mouse_sensitivity),
			-90,
			90)
		var camera_origin_rot_basis = Basis() # reset rotation
		var camera_rot_basis = Basis()
		camera_rot_basis = camera_rot_basis.rotated(Vector3(1, 0, 0), deg2rad(cumulative_rot_y)) # then rotate around X axis
		camera_origin_rot_basis = camera_origin_rot_basis.rotated(Vector3(0, 1, 0), deg2rad(cumulative_rot_x)) # then rotate around Y axis
		camera_origin.transform.basis = camera_origin_rot_basis
		camera.transform.basis = camera_rot_basis
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("teleport"):
		transform.origin = Vector3(0, 15, 0)
	
	if event.is_action_pressed("jump") and jumps_left > 0 and ticks_since_grounded < jump_tick_limit:
		jump()
		jumps_left -= 1
		
	if Input.is_action_just_pressed("toggle_flashlight"):
		if flashlight.is_visible_in_tree():
			flashlight.hide()
		else:
			flashlight.show()
	
	if event.is_action_pressed("primary_action"):
		weapon.fire(fire_mode, [camera.get_global_transform()])
	
	if event.is_action_pressed("select_fire_mode_0"):
		fire_mode = 0
	if event.is_action_pressed("select_fire_mode_1"):
		fire_mode = 1
	if event.is_action_pressed("select_fire_mode_2"):
		fire_mode = 2
"""

# Run per physics frame
func collect_inputs():
	var camera_origin_basis = camera_origin.get_global_transform().basis
	
	direction = Vector3()
	
	if Input.is_action_pressed("move_forwards"):
		direction -= camera_origin_basis.z
	elif Input.is_action_pressed("move_backwards"):
		direction += camera_origin_basis.z
	
	if Input.is_action_pressed("move_left"):
		direction -= camera_origin_basis.x
	elif Input.is_action_pressed("move_right"):
		direction += camera_origin_basis.x
	
	if Input.is_action_pressed("sprint"):
		sprinting = true
	else:
		sprinting = false
	
	
	direction = direction.normalized()

# -----------------------------------------------------------------------Utility
func take_snapshot() -> Vector3:
	return delta_position

func update_and_add_delta_p():
	var current_time = OS.get_ticks_usec()
	tick_length = current_time - last_queue_add_timestamp
	last_queue_add_timestamp = current_time
	
	var current_position = get_global_transform().origin
	delta_position = current_position - last_position
	last_position = current_position
	motion_time_queue.add_to_queue([tick_length, delta_position])

# using get_velocity_at_end_of_physics_frame is on average:
# ~%1.5 better than raw velocity for high-activity movement
# ~%3.5 better than raw velocity for medium-activity movement
# ~%2.7 better than no velocity for high-activity movement
# ~%7.0 better than no velocity for medium-activity movement
func get_motion_since(lag_time):
	var seconds_since_last_queue_add = (
		(OS.get_ticks_usec() - last_queue_add_timestamp) /
		1000000)
	return (
		get_velocity_at_end_of_physics_frame() * 
		seconds_since_last_queue_add +
		motion_time_queue.calculate_delta_p_prior_to_latest_physics_step(lag_time - seconds_since_last_queue_add))

# ----------------------------------------------------------------------------UI

func display_ammo_reserves():
	ui_ammo_reserves.set_text(str(weapon.ammo_remaining))
	ui_ammo_gauge.set_value(100 * float(weapon.clip_remaining) / weapon.clip_size_default)

func display_reload_progress():
	if weapon.ammo_remaining == 0:
		return
	var period = weapon.reload_time_default
	var tick = float(period) / 100
	var num_ticks = int(period / tick)
	for i in range(100):
		ui_ammo_gauge.set_value(ui_ammo_gauge.get_value() + 1)
		yield(get_tree().create_timer(tick), "timeout")

func display_health():
	ui_health_label.set_text(str(health))
	ui_health_gauge.set_value(health)

func display_damage_dealt(damage):
	ui_dealt_damage_label.set_text(str(int(damage)))
	if damage > 66:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_meg_damage_color)
		var ui_new_position = ui_dealt_damage_label.rect_position - Vector2(0, 50)
		animation_helper.interpolate_symmetric(
			interpolator,
			ui_dealt_damage_label,
			"rect_position",
			ui_new_position,
			0.4)
	elif damage > 30:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_big_damage_color)
	elif damage > 15:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_mid_damage_color)
	else:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_lil_damage_color)

# --------------------------------------------------------------------Networking
