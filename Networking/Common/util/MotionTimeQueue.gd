extends TimeQueue

onready var player = get_parent()

var rolling_sum_ticks = 9999999999
var rolling_delta_p_sum = Vector3()

# uses a timestamp_queue in parrallel with the data queue
var tick_queue = PoolIntArray()

func init_time_queue(tick_time=16.666666667, queue_length=960, data_source=parent, queue=PoolVector3Array()):
	self.tick_time = tick_time
	self.queue_length = queue_length
	self.data_source = data_source
	for i in range(queue_length):
		queue.append(Vector3(0,0,0))
		tick_queue.append(0)
	self.queue = queue

func add_to_queue(snapshot):
	# if we've run out of space, start over!
	if not current_queue_tail < queue_length:
		current_queue_tail = 0
	tick_queue.set(current_queue_tail, snapshot[0])
	queue.set(current_queue_tail, snapshot[1])
	current_queue_tail += 1
	ticks_since_start += 1

func add_to_queue_with_sequence_number(snapshot):
	if not current_queue_tail < queue_length:
		current_queue_tail = 0
	tick_queue.set(current_queue_tail, ticks_since_start)
	queue.set(current_queue_tail, snapshot)
	current_queue_tail += 1
	ticks_since_start += 1

func replay_since_tick(sequence_number) -> Vector3:
	var cumulative_movement = Vector3()
	var ticks_ago = 1
	var ticks_to_rewind = tick_queue[current_queue_tail - 1] - sequence_number
	while ticks_to_rewind > 0 and ticks_ago < queue_length:
		cumulative_movement = cumulative_movement + queue[current_queue_tail - ticks_ago]
		ticks_ago += 1
		ticks_to_rewind -= 1
	return cumulative_movement

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

#times in microseconds
func get_position_at_time_past(time_past):
	if time_past < 0:
		print("calculating future p is not possible")
		return player.get_global_transform().origin
	var time_counter = time_past
	var ticks_ago = 1
	while time_counter > 0:
		time_counter -= tick_queue[current_queue_tail - ticks_ago]
		ticks_ago += 1
		if ticks_ago > min(ticks_since_start, queue_length):
			print("calculating too far into the past")
			return queue[current_queue_tail]
	if ticks_ago == 2:
		return player.get_global_transform().origin
	else:
		return queue[current_queue_tail - (ticks_ago - 1)]

func get_cumulative_movement_usecs_before_step(time_preceding_last_queue_add):
	if time_preceding_last_queue_add < 0:
		print("calculating future p is not possible")
		return Vector3()
	var time_counter = time_preceding_last_queue_add
	var ticks_ago = 1
	var cumulative_movement = Vector3()
	while time_counter > 0:
		var index = current_queue_tail - ticks_ago
		time_counter -= tick_queue[index]
		cumulative_movement += queue[index]
		ticks_ago += 1
		if ticks_ago > min(ticks_since_start, queue_length):
			print("calculating too far into the past")
			return get_sum()
	return cumulative_movement

func get_earliest_position():
	pass

func get_sum():
	var sum = Vector3()
	for i in range(queue.size()):
		sum += queue[1]
	return sum
