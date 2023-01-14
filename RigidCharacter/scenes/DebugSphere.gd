extends MeshInstance

func _free(time):
	yield(get_tree().create_timer(time), "timeout")
	queue_free()
