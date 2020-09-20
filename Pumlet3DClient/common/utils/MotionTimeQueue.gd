extends "res://common/utils/TimeQueue.gd"

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
