extends KinematicBody

onready var client = get_node("/root/Client")
onready var camera_origin = $CameraOrigin
onready var camera = $CameraOrigin/Camera
onready var flashlight = $CameraOrigin/Camera/Flashlight
onready var shotgun = $CameraOrigin/Camera/Shotgun
onready var ui_ammo_reserves = $UI/Stats/Bars/Ammo/AmmoLabel/Background/Reserves
onready var ui_ammo_gauge = $UI/Stats/Bars/Ammo/AmmoGauge
onready var ui_health_label = $UI/Stats/Bars/Health/HealthLabel/Background/Number
onready var ui_health_gauge = $UI/Stats/Bars/Health/HealthGauge

var periodic_timer = Timer.new()
var periodic_timer_period = 0.5
var interpolator = Tween.new()

var health = 100

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_child(periodic_timer)
	periodic_timer.start(periodic_timer_period)
	periodic_timer.connect("timeout", self, "_periodic")
	add_child(interpolator)

func _periodic():
	display_health()


# ----------------------------------------------------------------------Movement
export var speed = 10
export var acceleration = 3
export var deceleration = 3
export var gravity = 1
export var jump_power = 80
var velocity = Vector3()
var direction = Vector3()
var ticks_since_grounded = 0
var jump_fuel = 0
var up_dir = Vector3()


func _physics_process(delta):
	var accel = acceleration
	if velocity.x * direction.x + velocity.z * direction.z < 0:
		accel = deceleration
	velocity = velocity.linear_interpolate(direction * speed, accel * delta)
	
	collect_inputs()
	
	if is_on_floor():
		ticks_since_grounded = 0
		jump_fuel = 30
		up_dir = get_floor_normal()
	else:
		ticks_since_grounded += 1
		jump_fuel -= 1
		up_dir = Vector3.UP
	
	if is_on_wall():
		if ticks_since_grounded < 80:
			velocity.y += gravity + 3.5
	velocity -= gravity * up_dir
	
	velocity = move_and_slide(
		velocity,
		Vector3.UP,
		true)

func jump():
	var jump_ticks_remaining = 8
	while jump_ticks_remaining > 0:
		velocity.y += gravity * jump_ticks_remaining
		yield(get_tree().create_timer(0.02),"timeout")
		jump_ticks_remaining -= 1
		if ticks_since_grounded < 30:
			ticks_since_grounded = 30

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
	
	if event.is_action_pressed("jump") and ticks_since_grounded < 30:
		jump()
		
	if Input.is_action_just_pressed("toggle_flashlight"):
		if flashlight.is_visible_in_tree():
			flashlight.hide()
		else:
			flashlight.show()
	
	if event.is_action_pressed("primary_action"):
		shotgun.fire(0, [camera.get_global_transform()])
		display_ammo_reserves()


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
	
	direction = direction.normalized()


# -----------------------------------------------------------------------Utility
# ----------------------------------------------------------------------------UI

func display_ammo_reserves():
	ui_ammo_reserves.set_text(str(shotgun.ammo_remaining))
	ui_ammo_gauge.set_value(100 * float(shotgun.ammo_remaining) / shotgun.ammo_default)

func display_health():
	ui_health_label.set_text(str(health))
	ui_health_gauge.set_value(health)
