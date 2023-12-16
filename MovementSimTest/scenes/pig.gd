extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _target_angle = 2.0

func _ready():
	print((Vector3(-29.354, 1.640, -101.500) - Vector3(-29.136, 1.509, -101.500)).normalized().dot(Vector3(0.500, 0.866, 0.000).normalized()))
#	var simulated_end = Vector3(10.17654, 7.169892, -45.8037)
#	print(simulated_end - 4.3 * 0.01780700683594 * Vector3(-0.064076, 0.057994, 0.326668).normalized())
#	var predicted_end = Vector3(10.18144, 7.166358, -45.80307)
#	print(predicted_end - 0.00506973266602 * Vector3(-0.064076, 0.057994, 0.326668).normalized())
#	print((predicted_end - simulated_end).normalized().dot(Vector3(-0.939693, 0.34202, 0).normalized()))
	change_target_angle()

func _physics_process(delta):
#	$MeshOrigin/Pig.transform.origin = (Vector3.UP * 0.05 * (sin(Time.get_ticks_msec() / 200.0) - 0.5))
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
