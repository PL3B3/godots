extends RigidBody

func test_motion(position, motion, result, exclude=[], radius=1) -> bool:
	$CollisionShape.shape.radius = radius
	return PhysicsServer.body_test_motion(get_rid(), Transform(Basis.IDENTITY, position), motion, false, result, true, exclude)
