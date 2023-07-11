extends RigidBody3D


func _physics_process(delta):
	for i in range(100):
		var state = PlayerPhysicsState.new(global_transform, Vector3.ZERO, int(delta))
