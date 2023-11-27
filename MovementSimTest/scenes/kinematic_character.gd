extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const FULL_ROTATION_DEGREES = 360
const MOUSE_SENSITIVITY = 0.2

@onready var camera = $Camera3D
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw = 0
var _pitch = 0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if (event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		_yaw = normalize_angle_to_positive_degrees(_yaw - (event.relative.x) * MOUSE_SENSITIVITY)
		_pitch = clamp(_pitch - (event.relative.y * MOUSE_SENSITIVITY), -90.0, 90.0)
	elif event.is_action_pressed("toggle_mouse_mode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	camera.position = position
	camera.rotation_degrees.y = _yaw
	camera.rotation_degrees.x = _pitch

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(_yaw))
	var direction = (facing_horizontal_direction_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()

func normalize_angle_to_positive_degrees(angle: float):
	angle = fmod(angle, FULL_ROTATION_DEGREES)
	return angle + FULL_ROTATION_DEGREES if angle < 0 else angle
