extends StaticBody3D

func _process(delta):
	global_transform = Transform3D(global_transform.basis.orthonormalized(), global_transform.origin)
	force_update_transform()

func _physics_process(delta):
	global_transform = Transform3D(global_transform.basis.orthonormalized(), global_transform.origin)
	force_update_transform()
