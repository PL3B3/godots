extends Node

var mtq = preload("res://client/utils/MotionTimeQueue.tscn")

func _ready():
	test_mtq_2()

func test_mtq():
	var mtq_0 = mtq.instance()
	add_child(mtq_0)
	mtq_0.init_time_queue(1, 10)
	for i in range(2 * mtq_0.queue_length):
		mtq_0.add_to_queue(Vector3(1, 0, 0))
	mtq_0.update_rolling_sum_ticks(5)
	for i in range(4):
		mtq_0.add_to_queue(Vector3(3, 0, 0))
	print(mtq_0.rolling_delta_p_sum == Vector3(13, 0, 0))
	for i in range(3):
		mtq_0.add_to_queue(Vector3(5 + i, 0, 0))
	print(mtq_0.rolling_delta_p_sum == Vector3(19, 0, 0))
	print(
		mtq_0.calculate_delta_p_prior_to_latest_physics_step(4)
		==
		Vector3(16, 0, 0))
	print(mtq_0.current_queue_tail)
	print(mtq_0.queue)
	print(mtq_0.calculate_delta_p_prior_to_latest_physics_step(3.3))
	print(mtq_0.rolling_delta_p_sum)
	print(mtq_0.calculate_delta_p_prior_to_latest_physics_step_rolling(7.2))

func test_mtq_2():
	var mtq_0 = mtq.instance()
	mtq_0.init_time_queue(1, 10)
	add_child(mtq_0)
	for i in range(2 * mtq_0.queue_length):
		mtq_0.add_to_queue(Vector3(i, 0, 0))
	print(mtq_0.queue)
	print(mtq_0.current_queue_tail)
	print(mtq_0.calculate_delta_p_prior_to_latest_physics_step(3.2))

func test_mtq_performance():
	var mtq_0 = mtq.instance()
	add_child(mtq_0)
	mtq_0.init_time_queue(0.3, 200)
	for i in range(2 * mtq_0.queue_length):
		mtq_0.add_to_queue(Vector3(3.4, 0, 0))
	mtq_0.update_rolling_sum_ticks(40)
	var begin_time = OS.get_ticks_msec()
	for i in range(1000000):
		mtq_0.calculate_delta_p_prior_to_latest_physics_step(7.2)
	print(OS.get_ticks_msec() - begin_time)
