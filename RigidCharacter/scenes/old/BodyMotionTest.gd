extends Node

onready var mark = preload("res://scenes/DebugSphere.tscn")
onready var rb = $RigidBody
var rng = RandomNumberGenerator.new()
var h_spread = 30

func _physics_process(delta):
	if Input.is_action_just_pressed("alt_click"):
		var res = PhysicsTestMotionResult.new()
		var pos = Vector3(rng.randf_range(-h_spread, h_spread), rng.randf_range(0, 10), rng.randf_range(-h_spread, h_spread))
		var hit_mark = mark.instance()
		hit_mark.transform.origin = pos
		add_child(hit_mark)
		if test_motion(pos, Vector3.DOWN * 10, res):
			pvecs([pos, res.collision_normal, res.collision_point, res.motion])
		

func test_motion(position:Vector3, motion:Vector3, result:PhysicsTestMotionResult) -> bool:
	return PhysicsServer.body_test_motion(rb.get_rid(), Transform(Basis.IDENTITY, position), motion, false, result)
	
func vtos(vector:Vector3):
	return "(%+.3f, %+.3f, %+.3f)" % [vector.x, vector.y, vector.z]

func pvecs(vecs):
	var vec_str = ""
	for vec in vecs:
		vec_str += vtos(vec) + " - "
	print(vec_str)
