extends KinematicBody

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
onready var time_queue = $TimeQueue

var ui_meg_damage_color = Color.turquoise
var ui_big_damage_color = Color.purple
var ui_mid_damage_color = Color.salmon
var ui_lil_damage_color = Color.gray

var periodic_timer = Timer.new()
var periodic_timer_period = 0.5
var interpolator = Tween.new()
var animation_helper = preload("res://client/utils/AnimationHelper.gd")

var health = 100
var fire_mode = 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_child(periodic_timer)
	periodic_timer.start(periodic_timer_period)
	periodic_timer.connect("timeout", self, "_periodic")
	add_child(interpolator)
	weapon.connect("clip_changed", self, "display_ammo_reserves")
	weapon.connect("recoil", self, "dash")
	weapon.connect("reload_started", self, "display_reload_progress")
	weapon.connect("dealt_damage", self, "display_damage_dealt")
	weapon.ignored_objects.append(self)
	time_queue.init_time_queue(0.01)

func _periodic():
	display_health()


# ----------------------------------------------------------------------Movement
export var speed = 8
export var acceleration = 3
export var deceleration = 3
export var gravity = 0.8
export var jump_cap = 1
export var jump_tick_limit = 40
export var wall_climb_speed = 1.5
export var wall_climb_tick_limit = 40
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

func _physics_process(delta):
	var current_position = get_global_transform().origin
	delta_position = current_position - last_position
	last_position = current_position
	
	velocity = velocity.linear_interpolate(
		direction * speed * (1 + 2 * int(sprinting)),
		acceleration * delta)
	
	collect_inputs()
	
	if is_on_floor():
		up_dir = get_floor_normal()
	else:
		up_dir = Vector3.UP
	
	if is_on_wall():
		ticks_since_walled = 0
	else:
		ticks_since_walled += 1
	if ticks_since_walled < 5:
		if ticks_spent_wall_climbing < wall_climb_tick_limit:
			velocity.y += wall_climb_speed
			ticks_spent_wall_climbing += 1
	velocity -= gravity * up_dir
	
	velocity = move_and_slide(
		velocity,
		Vector3.UP,
		true)
	
	
	if is_on_floor():
		ticks_since_grounded = 0
		ticks_spent_wall_climbing = 0
		jumps_left = jump_cap
	else:
		ticks_since_grounded += 1

func jump():
	dash(Vector3(0, 1, 0), gravity * 7, 14)

func dash(direction: Vector3, speed: float, ticks: int):
	var dash_ticks_remaining = ticks
	while dash_ticks_remaining > 0:
		velocity += direction.normalized() * speed * (float(dash_ticks_remaining) / ticks)
		yield(get_tree().create_timer(0.02),"timeout")
		dash_ticks_remaining -= 1

# -------------------------------------------------------------------------Input
export var mouse_sensitivity = 0.05
var camera_x_rotation = 0

func _input(event):
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_origin.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		var x_delta = event.relative.y * mouse_sensitivity
		if camera_x_rotation + x_delta > -90 and camera_x_rotation + x_delta < 90: 
			camera.rotate_x(deg2rad(-x_delta))
			camera_x_rotation += x_delta
	
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
	elif damage > 40:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_big_damage_color)
	elif damage > 15:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_mid_damage_color)
	else:
		ui_dealt_damage_label.set("custom_colors/font_color", ui_lil_damage_color)

# --------------------------------------------------------------------Networking
func take_snapshot() -> Vector3:
	return delta_position
