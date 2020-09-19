extends "res://client/utils/TimeQueue.gd"

var rolling_sum_ticks = 9999999999
var rolling_delta_p_sum = Vector3()

# uses a timestamp_queue in parrallel with the data queue
var tick_queue = PoolIntArray()

func init_time_queue(tick_time=0.0166666666666666, queue_length=240, data_source=parent, queue=PoolVector3Array()):
	self.tick_time = tick_time
	self.queue_length = queue_length
	self.data_source = data_source
	for i in range(queue_length):
		queue.append(Vector3(0,0,0))
		tick_queue.append(0)
	self.queue = queue

"""
func calculate_delta_p_prior_to_latest_physics_step(time_preceding_last_physics_step):
	if time_preceding_last_physics_step < 0:
		print("calculating future p is not possible")
		return Vector3()
	var th = time_preceding_last_physics_step
	# time in full ticks (floored)
	var tht : int = floor(th / tick_time)
	if tht > min(ticks_since_start, queue_length):
		#print("calculating too far into the past")
		return get_sum()
	else:
		# left over error in ticks
		var tlet = (th - tht * tick_time) / tick_time
		var delta_p = Vector3()
		#print("tht: " + str(tht))
		for ticks_ago in range(1, tht + 1):
			var index = current_queue_tail - ticks_ago
			delta_p += queue[index]
		delta_p += tlet * queue[current_queue_tail - (tht + 1)]
		return delta_p
"""
func add_to_queue(snapshot):
	# if we've run out of space, start over!
	if not current_queue_tail < queue_length:
		current_queue_tail = 0
	tick_queue.set(current_queue_tail, snapshot[0])
	queue.set(current_queue_tail, snapshot[1])
	current_queue_tail += 1
	ticks_since_start += 1


func calculate_delta_p_prior_to_latest_physics_step(time_preceding_last_physics_step):
	if time_preceding_last_physics_step < 0:
		print("calculating future p is not possible")
		return Vector3()
	var th = time_preceding_last_physics_step
	var delta_p = Vector3()
	var ticks_ago = 1
	while th > 0:
		var index = current_queue_tail - ticks_ago
		var tick_delta_p = queue[index]
		var tick_length = tick_queue[index]
		delta_p += (
			tick_delta_p * 
			min(th, tick_length) 
			/ tick_length)
		th -= tick_length
		ticks_ago += 1
		if ticks_ago > min(ticks_since_start, queue_length):
			print("calculating too far into the past")
			return get_sum()
	return delta_p

func get_sum():
	var sum = Vector3()
	for i in range(queue.size()):
		sum += queue[1]
	return sum
func update_rolling_sum_ticks(avg_two_way_ping_seconds):
	var new_ticks = int(avg_two_way_ping_seconds / tick_time)
	if new_ticks > min(ticks_since_start, queue_length):
		print("not enough ticks to calculate rolling sum")
	else:
		rolling_sum_ticks = new_ticks
		rolling_delta_p_sum = Vector3()
		for ticks_ago in range(1, rolling_sum_ticks + 1):
			var index = current_queue_tail - ticks_ago
			rolling_delta_p_sum += queue[index]

func calculate_delta_p_prior_to_latest_physics_step_rolling(time_preceding_last_physics_step):
	if time_preceding_last_physics_step < 0:
		print("calculating future p is not possible")
		return Vector3()
	var th = time_preceding_last_physics_step
	var rstme = th - rolling_sum_ticks * tick_time
	# error in full ticks (floored)
	var rstke : int = floor(abs(rstme) / tick_time)
	# left over error in ticks (direction agnostic)
	var rstkle = (abs(rstme) - (rstke * tick_time)) / tick_time
	var correction_vector = Vector3()
	if rstme >= 0: # th farther in past than rolling sum
		var edge_error_tick_index = rolling_sum_ticks + rstke
		for ticks_ago in range(rolling_sum_ticks + 1, edge_error_tick_index + 1):
			var index = current_queue_tail - ticks_ago
			correction_vector += queue[index]
		correction_vector += queue[current_queue_tail - (edge_error_tick_index + 1)] * rstkle
	else:
		var edge_error_tick_index = 1 + rolling_sum_ticks - rstke
		for ticks_ago in range(edge_error_tick_index, 1 + rolling_sum_ticks):
			var index = current_queue_tail - ticks_ago
			correction_vector -= queue[index]
		correction_vector -= queue[current_queue_tail - (edge_error_tick_index - 1)] * rstkle
	return rolling_delta_p_sum + correction_vector

#func add_to_queue(snapshot):
#	.add_to_queue(snapshot)
#	calculate_rolling_delta_p_sum()

func calculate_rolling_delta_p_sum():
	if not rolling_sum_ticks > min(ticks_since_start, queue_length):
		rolling_delta_p_sum += get_snapshot_x_ticks_ago(1) - get_snapshot_x_ticks_ago(rolling_sum_ticks + 1)
