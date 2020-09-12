extends KinematicBody

onready var client = get_node("/root/Client")
onready var camera_origin = $CameraOrigin
onready var camera = $CameraOrigin/Camera

var periodic_timer = Timer.new()
var periodic_timer_period = 0.5

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_child(periodic_timer)
	periodic_timer.start(periodic_timer_period)
	periodic_timer.connect("timeout", self, "_periodic")

func _periodic():
	client.current_map.get_ground_name(transform.origin)

# ----------------------------------------------------------------------Movement
export var speed = 20
export var acceleration = 4
export var gravity = 2
export var jump_power = 60
var velocity = Vector3()
var direction = Vector3()
var ticks_since_grounded = 0


func _physics_process(delta):
	velocity = velocity.linear_interpolate(direction * speed, acceleration * delta)
	
	collect_inputs()
	
	var up_dir = Vector3.UP
	
	if is_on_floor():
		var floor_normal = get_floor_normal()
		velocity -= gravity * floor_normal
		ticks_since_grounded = 0
		up_dir = floor_normal
	else:
		velocity.y -= gravity
		ticks_since_grounded += 1
	
	if Input.is_action_just_pressed("jump") and ticks_since_grounded < 30:
		velocity.y += jump_power
	
	velocity = move_and_slide(
		velocity,
		Vector3.UP,
		true)

# -------------------------------------------------------------------------Input
export var mouse_sensitivity = 0.1
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
		transform.origin = Vector3(0, 40, 0)


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
