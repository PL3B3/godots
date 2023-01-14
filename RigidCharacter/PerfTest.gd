extends RigidBody

func _physics_process(delta):
	return
	for i in 100:
		test_motion()

func cast_shape():
	var space_state = get_world().direct_space_state
	var shape_query = PhysicsShapeQueryParameters.new()
	var cast_shape = SphereShape.new()
	shape_query.exclude = [self]
	shape_query.set_shape(cast_shape)
	shape_query.transform.origin = global_transform.origin
	var result = space_state.cast_motion(shape_query, Vector3.DOWN)
#    shape_query.transform.origin += Vector3.DOWN 
#    var result2 = space_state.get_rest_info(shape_query)

func test_motion():
	var result = PhysicsTestMotionResult.new()
	PhysicsServer.body_test_motion(get_rid(), Transform(Basis.IDENTITY, transform.origin), Vector3.DOWN, false, result)
