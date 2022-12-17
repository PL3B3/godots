extends KinematicBody

class_name Mover

enum MOVE { # move instruc
	PROCESSED, # has been processed
	JUMP,
	X_DIR,
	Z_DIR,
	LOOK, # yaw and pitch
	LOOK_DELTA} # did look change since last frame	

export(NodePath) var camera_path:NodePath
export(NodePath) var move_collider_path:NodePath
export(NodePath) var hurt_collider_path:NodePath
onready var camera:Camera = get_node(camera_path)
onready var move_collider:CollisionShape = get_node(move_collider_path)
onready var hurt_collider:CollisionShape = get_node(hurt_collider_path)

var slip_sphere:SphereShape

# -------------------------------------------------------------Movement Settings
var jump_force := 15.0
var jump_grace_ticks := 8
var jump_try_ticks := 4

var ticks_until_in_air := 5

var gravity := 0.75
var speed := 7.5
var speed_limit := 25.5
var h_speed_limit_sqr := pow(speed_limit, 2)
var speed_zero_limit := 0.0005 # if speed^2 falls below this, set it to 0
var acceleration := 11.0
var acceleration_in_air := 3.0

var is_grounded_threshold := 0.01
var ground_snap_threshold := 0.0
var slip_radius := 0.9
var character_feet_offset := 1.0 # how far below character origin is its feet?

# -----------------------------------------------------------------Movement Vars
var yaw := 0.0
var pitch := 0.0
var ticks_since_last_jump := jump_grace_ticks
var ticks_since_on_floor := 0
var ticks_since_on_wall := 0
var velocity := Vector3()
var is_grounded_query:PhysicsShapeQueryParameters
var move_slice:Array

# ------------------------------------------------------------------Network vars
var move_buffer:PoolBuffer

var last_frame_yaw := 0.0
var avg_yaw_delta := 0.0

func _ready():
	init_grounded_query()

	init_move_recording()

func init_grounded_query():
	slip_sphere = SphereShape.new()
	slip_sphere.radius = slip_radius
	
	is_grounded_query = PhysicsShapeQueryParameters.new()
	is_grounded_query.exclude = [
		self, 
		move_collider, 
		hurt_collider]
	is_grounded_query.margin = 0.05
	is_grounded_query.set_shape(slip_sphere)

func init_move_recording():
	move_slice = []
	move_slice.resize(MOVE.size())
	move_slice[MOVE.PROCESSED] = 0
	move_slice[MOVE.JUMP] = 0
	move_slice[MOVE.X_DIR] = 0
	move_slice[MOVE.Z_DIR] = 0
	move_slice[MOVE.LOOK] = Vector2(0.0, 0.0)
	move_slice[MOVE.LOOK_DELTA] = 0

	var move_stubs = []
	move_stubs.resize(MOVE.size())
	move_stubs[MOVE.PROCESSED] = PoolByteArray()
	move_stubs[MOVE.JUMP] = PoolByteArray()
	move_stubs[MOVE.X_DIR] = PoolByteArray()
	move_stubs[MOVE.Z_DIR] = PoolByteArray()
	move_stubs[MOVE.LOOK] = PoolVector2Array()
	move_stubs[MOVE.LOOK_DELTA] = PoolByteArray()
	move_buffer = PoolBuffer.new(move_stubs)

func get_dist_to_ground():
	"""
		Custom implementation of is_on_floor()
		Not needed when using bulletphysics
	"""
	var space_state = get_world().direct_space_state
	is_grounded_query.transform = get_global_transform()
	is_grounded_query.transform.origin += ( # make slip sphere touch ground
		Vector3.DOWN * (character_feet_offset - slip_radius))
	var cast_result = space_state.cast_motion(is_grounded_query, Vector3.DOWN)
	return cast_result[0]

func calculate_movement(delta:float):
	var target_velocity = (
		speed * (
			move_slice[MOVE.X_DIR] * transform.basis.x +
			move_slice[MOVE.Z_DIR] * -transform.basis.z).normalized() +
		velocity.y * Vector3.UP)
	
	if ticks_since_on_floor > ticks_until_in_air:
		velocity = velocity.linear_interpolate(
			target_velocity, acceleration_in_air * delta)
	else:
		velocity = velocity.linear_interpolate(
			target_velocity, acceleration * delta)
	
	if (move_slice[MOVE.JUMP] and 
	ticks_since_on_floor < jump_grace_ticks and
	ticks_since_last_jump > jump_grace_ticks):
		velocity.y = jump_force
		ticks_since_on_floor = jump_grace_ticks
		ticks_since_last_jump = 0
	
	if is_on_floor():
		print("floored")
		velocity -= gravity * get_floor_normal()
		if abs(velocity.y) < 0.05:
			velocity.y = 0
		ticks_since_on_floor = 0
	else:
		print("air")
		velocity -= gravity * Vector3.UP
		ticks_since_on_floor += 1
	
	ticks_since_last_jump += 1
	
	var vel_h_mag_sqr = pow(velocity.x, 2) + pow(velocity.z, 2)
	if vel_h_mag_sqr > h_speed_limit_sqr:
		var h_scale_fac = sqrt(h_speed_limit_sqr / vel_h_mag_sqr)
		velocity.x *= h_scale_fac
		velocity.z *= h_scale_fac
	
	var vel_mag_sqr = vel_h_mag_sqr + pow(velocity.y, 2)
	if vel_mag_sqr < speed_zero_limit and ticks_since_on_floor == 0:
		velocity = Vector3()

func apply_movement():
	if not velocity.is_equal_approx(Vector3()):
		var slid_vel = move_and_slide(velocity, Vector3.UP, true)
		velocity = slid_vel

func show_angle_change():
	avg_yaw_delta = (
		0.9 * avg_yaw_delta + 
		0.1 * shortest_deg_between(yaw, last_frame_yaw))
	print(shortest_deg_between(yaw, last_frame_yaw))
	last_frame_yaw = yaw

static func deg_to_deg360(deg : float):
	deg = fmod(deg, 360.0)
	if deg < 0.0:
		deg += 360.0
	return deg

func shortest_deg_between(deg1 : float, deg2 : float):
	return min(
		abs(deg1 - deg2),
		min(abs((deg1 - 360.0) - deg2), abs((deg2 - 360.0) - deg1)))
