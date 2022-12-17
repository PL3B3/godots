extends RigidBody

var clicks = 0
func _physics_process(delta):
    if Input.is_action_just_pressed("left_click"):
        clicks += 1
        linear_velocity = Vector3(120, 0, 0)
        PhysicsServer.simulate(delta)
        var space_state = get_world().direct_space_state
        var ray_start = Vector3(2 * clicks, 2, 0)
        var ray_end = Vector3(2 * clicks, 0, 0)
        var result = space_state.intersect_ray(ray_start, ray_end)
        if result and is_instance_valid(result.collider):
            print("Hit ", result.collider)
        linear_velocity = Vector3()
#    print(global_transform.origin)

#func _integrate_forces(state):
#    var space_state = get_world().direct_space_state
#    var ray_start = camera.global_transform.origin
#    var ray_vec = -200 * camera.global_transform.basis.z
#    var ray_end = ray_start + ray_vec
#    var result = space_state.intersect_ray(ray_start, ray_end, [self])
#    if result and is_instance_valid(result.collider):
#        print("Hit ", result.collider)
