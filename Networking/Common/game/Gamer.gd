extends KinematicBody

export(NodePath) var camera_path : NodePath
export(NodePath) var collider_path : NodePath

onready var camera : Camera = get_node(camera_path)
onready var collider : CollisionShape = get_node(collider_path)

onready var target = preload("res://Common/game/Target.tscn")

var mouse_sensitivity := 0.04
var yaw := 0.0
var pitch := 0.0

var z_dir := 0
var x_dir := 0

var jump_force := 10.0
var jump_grace_ticks := 6
var ticks_since_last_jump := 0
var ticks_since_on_floor := 0
var ticks_until_in_air := 5
var ticks_since_on_wall := 0
var gravity := 30.0
var speed := 7.5
var velocity := Vector3()
var acceleration := 11.0
var acceleration_in_air := 3.5

var raycast_this_physics_frame = false
var target_position = Vector3(0.0, 2.0, -15.0)
var target_to_shoot = null

var last_frame_yaw := 0.0
var avg_yaw_delta := 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_to_shoot = target.instance()
	get_tree().get_root().call_deferred("add_child", target_to_shoot)
	
	var packet : PoolByteArray = PoolByteArray()
	packet.push_back(-1)
	print(packet[0])

func _unhandled_input(event):
	if event.is_action_pressed("click"):
		raycast_this_physics_frame = true
		
	if (event is InputEventMouseMotion 
		&& Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		var yaw_delta = -event.relative.x * mouse_sensitivity
		var pitch_delta = event.relative.y * mouse_sensitivity
		yaw += yaw_delta
		yaw = deg_to_deg360(yaw)
		
		rotation_degrees.y = yaw
		orthonormalize()
		pitch = clamp(
			pitch - pitch_delta, 
			-90.0, 
			90.0
			)
		camera.rotation_degrees.x = pitch
		camera.orthonormalize()
		
	elif event.is_action_pressed("toggle_mouse_mode"):
		var new_mouse_mode
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			new_mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			new_mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(new_mouse_mode)
		
	elif event.is_action_pressed("jump"):
		if (ticks_since_on_floor < jump_grace_ticks
		&& ticks_since_last_jump > jump_grace_ticks):
			velocity.y = jump_force
			ticks_since_on_floor = jump_grace_ticks
			ticks_since_last_jump = 0
#		if gravity > 0:
#			gravity = 0
#			velocity.y = 0
#		else:
#			gravity = 30

func _process(delta):
	pass

func _physics_process(delta):
	handle_poll_input()
	move(delta)
	
#	avg_yaw_delta = (
#		0.9 * avg_yaw_delta + 
#		0.1 * shortest_deg_between(yaw, last_frame_yaw)
#		)
#	last_frame_yaw = yaw
	
	if raycast_this_physics_frame:
		target_to_shoot.transform.origin = target_position
		target_to_shoot.force_update_transform()
		var space_state = get_world().direct_space_state
		var result = space_state.intersect_ray(Vector3(10.0, 2.0, 3.0), target_position)
		if result and is_instance_valid(result.collider):
			pass
			#print(result.collider_id)
			#result.collider.queue_free()
		raycast_this_physics_frame = false
		target_to_shoot.transform.origin = Vector3(0, 0, 0)

func handle_poll_input():
	z_dir = 0
	x_dir = 0
	
	if Input.is_action_pressed("move_forward"):
		z_dir -= 1
	if Input.is_action_pressed("move_backward"):
		z_dir += 1
	if Input.is_action_pressed("move_left"):
		x_dir -= 1
	if Input.is_action_pressed("move_right"):
		x_dir += 1

func move(delta):
	var position_before_movement = get_global_transform().origin
		
	var target_velocity = (
		speed *
		(z_dir * transform.basis.z + x_dir * transform.basis.x).normalized() +
		velocity.y * Vector3.UP)
	
	if ticks_since_on_floor > ticks_until_in_air:
		velocity = velocity.linear_interpolate(
			target_velocity, acceleration_in_air * delta)
	else:
		velocity = velocity.linear_interpolate(
			target_velocity, acceleration * delta)
	
	if is_on_floor():
		velocity -= gravity * delta * get_floor_normal()
		ticks_since_on_floor = 0
	else:
		velocity -= gravity * delta * Vector3.UP
		ticks_since_on_floor += 1
	
	if is_on_wall():
		ticks_since_on_wall = 0
	else:
		ticks_since_on_wall += 1
	
	ticks_since_last_jump += 1
	
	# Movement code proper
	var slid_vel = move_and_slide(
		velocity,
		Vector3.UP,
		true)
	
	velocity = slid_vel

func deg360_to_short(deg : float) -> int:
	return lerp(0, 65535, deg_to_deg360(deg) / 360.0)

static func deg_to_deg360(deg : float):
	deg = fmod(deg, 360.0)
	if deg < 0.0:
		deg += 360.0
	return deg

func shortest_deg_between(deg1 : float, deg2 : float):
	return min(
		abs(deg1 - deg2),
		min(
			abs((deg1 - 360.0) - deg2),
			abs((deg2 - 360.0) - deg1)
			)
		)

# takes the players 0 to 360 degree yaw and -90 to 90 degree pitch
# converts into a PoolByteArray of length 3
# little endian
func encode_player_rotation(yaw: float, pitch: float):
	pass

# a 1:1 function with domain and range 0.0 to 1.0 
# used to map normalized player camera pitch to a 6-bit int
# corresponds to:
# y = 0.5x WHEN 0 < x < 0.25
# y = 1.5x - 0.25 WHEN 0.25 < x < 0.75
# y = 0.5x + 0.5 WHEN 0.75 < x < 1.0
func pitch_to_bit6_lerp_map(lerp_in: float) -> float:
	return lerp_in

# inverse of pitch_to_bit6_lerp_map
func bit6_to_pitch_lerp_map(lerp_in: float):
	return lerp_in
