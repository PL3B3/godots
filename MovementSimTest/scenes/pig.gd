extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _target_angle = 2.0

func _ready():
	change_target_angle()

func _physics_process(delta):
	$MeshOrigin/Pig.transform.origin = (Vector3.UP * 0.05 * (sin(Time.get_ticks_msec() / 200.0) - 0.5))
#	$Body.rotation.z -= delta * 4 # 0.5 * (sin(Time.get_ticks_msec() / 300.0) - 0.3)
#	rotation.y = lerp(rotation.y, _target_angle, delta)
	var current_look_direction = -transform.basis.z
	var target_look_direction = Vector3.FORWARD.rotated(Vector3.UP, _target_angle)
	var interpolated_look_direction = current_look_direction.slerp(target_look_direction, delta)
	look_at(position + interpolated_look_direction)
	velocity = -0.2 * transform.basis.z
	move_and_slide()


func change_target_angle():
	_target_angle = rng.randf_range(0, 2 * PI)
	get_tree().create_timer(rng.randf_range(5, 10)).timeout.connect(change_target_angle)
