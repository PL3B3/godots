extends KinematicBody

# ------------------------------------------------------------------Helper Nodes
onready var client = get_node("/root/Server")
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

var interpolator = Tween.new()
var animation_helper = preload("res://common/utils/AnimationHelper.gd")

# -----------------------------------------------------------------------UI Vars
var ui_meg_damage_color = Color.turquoise
var ui_big_damage_color = Color.purple
var ui_mid_damage_color = Color.salmon
var ui_lil_damage_color = Color.gray

# ---------------------------------------------------------------------Misc Vars
var error_avg = 0
var new_error_weight = 0.1

# ---------------------------------------------------------------------Game Vars
var health_default = 160
var health = health_default
var vulnerability_default = 1
var vulnerability = vulnerability_default
var team : int
var species : int

# -----------------------------------------------------------------Movement Vars
enum DIRECTION {STOP, NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}
var speed = 5
var speed_mult = 1
var acceleration = 6
var acceleration_air = 2
var air_control = 0.3
var gravity = 0.8
var jump_cap = 1
var jump_tick_limit = 40
var wall_climb_speed = 1.5
var wall_climb_tick_limit = 50
var ticks_spent_pushing_against_foot_of_wall = 0
var velocity = Vector3()
var direction = Vector3()
var ticks_since_grounded = 0
var ticks_since_walled = 0
var ticks_spent_wall_climbing = 0
var jumps_left = 0
var up_dir = Vector3()
var sprinting = false

var dash_ticks_dict = {}
# leftover velocity from last frame, which is built upon 
# next frame by dashes, gravity, etc
var last_frame_final_velocity : Vector3
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

# ---------------------------------------------------------------Networking Vars
var initialization_attributes = [
	"velocity", 
	"health", 
	"speed_mult", 
	"vulnerability"] # things you need to sync to copy an old player to a new client 


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	#print(physics_tick_length)
	motion_time_queue.init_time_queue(physics_tick_length, int(4 / physics_tick_length))
	
	add_child(interpolator)
	
	weapon.connect("clip_changed", self, "display_ammo_reserves")
	weapon.connect("recoil", self, "dash")
	weapon.connect("reload_started", self, "display_reload_progress")
	weapon.connect("dealt_damage", self, "display_damage_dealt")
	weapon.ignored_objects.append(self)
	
	display_ammo_reserves()


func _periodic(timer_period):
#	display_health()
#	var real_dist_moved = get_global_transform().origin - last_period_position
#	var error = real_dist_moved - get_displacement_usecs_ago(timer_period * 1000000)
#	print(get_motion_since(periodic_timer_period * 1000000))
#	print(real_dist_moved)
#	if real_dist_moved.length() > 0:
#		var pcnt_error = 100 * error.length() / real_dist_moved.length()
#		print(pcnt_error)
#		print("Overtime: %10d. error pcnt: %5.2f" % [OS.get_ticks_usec() - last_queue_add_timestamp, pcnt_error])
#		if error_avg == 0:
#			print("first_error")
#			error_avg = pcnt_error
#		else:
#			error_avg = (error_avg + (new_error_weight * pcnt_error)) / (1 + new_error_weight)
#	print("%6.3f error | overtime is %4d" % [error_avg, OS.get_ticks_usec() - last_queue_add_timestamp])
#	last_period_position = get_global_transform().origin
#	print(phys_tick_avg)
	pass

# ----------------------------------------------------------------------Movement

func _physics_process(delta):
#	update_and_add_delta_p()
	update_motion_time_tracking()
	
	var accel_to_use = acceleration
	if is_on_floor():
		up_dir = get_floor_normal()
	else:
		up_dir = Vector3.UP
		if not is_on_wall():
			accel_to_use = acceleration_air
	
	velocity = velocity.linear_interpolate(
		direction * (speed * speed_mult + air_control * velocity.length()),
		accel_to_use * delta)
	
	
	if is_on_wall():
		ticks_since_walled = 0
		ticks_spent_pushing_against_foot_of_wall += 1
	else:
		ticks_since_walled += 1
	if ticks_since_walled < 5:
		if ticks_spent_wall_climbing < wall_climb_tick_limit:
			if ticks_spent_pushing_against_foot_of_wall > 3:
				velocity.y += wall_climb_speed * speed_mult
				ticks_spent_wall_climbing += 1
	else:
		ticks_spent_pushing_against_foot_of_wall = 0
	velocity -= gravity * up_dir
	
	for dash_vector in dash_ticks_dict:
		var ticks_left = dash_ticks_dict[dash_vector]
		if ticks_left > 0:
			velocity += dash_vector
			dash_ticks_dict[dash_vector] -= 1
		else:
			dash_ticks_dict.erase(dash_vector)
	
#	last_queue_add_timestamp = OS.get_ticks_usec()
#	motion_time_queue.add_to_queue([delta, velocity * delta])
	
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
	
#	direction = Vector3()

func jump():
	dash(Vector3(0, 1, 0), gravity * 3, 12)
	jumps_left -= 1

func dash(direction: Vector3, speed: float, ticks: int):
	dash_ticks_dict[direction * speed] = ticks

# -----------------------------------------------------------------Input Methods

func set_camera_rotation(x_total_rot, y_total_rot):
	var camera_origin_rot_basis = Basis() # reset rotation
	var camera_rot_basis = Basis()
	camera_rot_basis = camera_rot_basis.rotated(Vector3(1, 0, 0), deg2rad(y_total_rot)) # then rotate around X axis
	camera_origin_rot_basis = camera_origin_rot_basis.rotated(Vector3(0, 1, 0), deg2rad(x_total_rot)) # then rotate around Y axis
	camera_origin.transform.basis = camera_origin_rot_basis
	camera.transform.basis = camera_rot_basis

func toggle_mouse_mode(new_mouse_mode):
	Input.set_mouse_mode(new_mouse_mode)

func teleport():
	transform.origin = Vector3(0, 15, 0)

func toggle_flashlight(turn_light_on):
	if turn_light_on:
		flashlight.show()
	else:
		flashlight.hide()

func primary_action(fire_parameters):
	weapon.fire(0, fire_parameters)

func secondary_action(fire_parameters):
	weapon.fire(1, fire_parameters)

func tertiary_action(fire_parameters):
	weapon.fire(2, fire_parameters)

func set_direction(direction_num):
	var camera_origin_basis = camera_origin.get_global_transform().basis
	
	var cam_z = camera_origin_basis.z
	var cam_x = camera_origin_basis.x
	
	match direction_num:
		DIRECTION.NORTH:
			direction = -cam_z
		DIRECTION.NORTHEAST:
			direction = cam_x - cam_z
		DIRECTION.NORTHWEST:
			direction = -cam_z - cam_x
		DIRECTION.EAST:
			direction = cam_x
		DIRECTION.WEST:
			direction = -cam_x
		DIRECTION.SOUTH:
			direction = cam_z
		DIRECTION.SOUTHEAST:
			direction = cam_z + cam_x
		DIRECTION.SOUTHWEST:
			direction = cam_z - cam_x
		DIRECTION.STOP:
			direction = Vector3()
		_:
			direction = Vector3()
	
	direction = direction.normalized()

# -----------------------------------------------------------------------Utility
func update_motion_time_tracking():
	var current_time = OS.get_ticks_usec()
	tick_length = current_time - last_queue_add_timestamp
	last_queue_add_timestamp = current_time
	motion_time_queue.add_to_queue([tick_length, get_global_transform().origin])

# accounts for microseconds since last frame
func get_displacement_usecs_ago(time_ago):
	var microseconds_since_last_queue_add = OS.get_ticks_usec() - last_queue_add_timestamp
	var displacement = get_global_transform().origin - motion_time_queue.get_position_at_time_past(time_ago - microseconds_since_last_queue_add)
	return displacement

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
	elif damage > 35:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_big_damage_color)
	elif damage > 15:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_mid_damage_color)
	else:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_lil_damage_color)

# --------------------------------------------------------------------Networking

func set_basic_values(species, team, origin):
	self.species = species
	self.team = team
	transform.origin = origin

# Array, not dictionary, optimizing for network usage
func get_initialization_values():
	var initialization_values = {}
	for attrib in initialization_attributes:
		initialization_values[attrib] = get(attrib)
	return initialization_values

func set_initialization_values(initialization_values):
	if initialization_values.size() == initialization_attributes.size():
		for attrib in initialization_values:
			set(attrib, initialization_values[attrib])
	else:
		print("Given " + str(initialization_values.size()) + " values, but expected " + str(initialization_attributes.size()))

func set_team(team_num: int):
	if team_num < 0:
		team_num = 0
	elif team_num > 5:
		team_num = 5
	
	team = team_num
	
	# Set collision layer to team_num only
	for l in range(0,6):
		set_collision_layer_bit(l, l == team_num)
	
	# Set mask to include all but our team
	for t in range(0,6):
		set_collision_mask_bit(t, t != team_num)
