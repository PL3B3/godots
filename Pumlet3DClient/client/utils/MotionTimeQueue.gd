extends "res://client/utils/TimeQueue.gd"

var rolling_sum_ticks
var rolling_delta_p_sum = Vector3()

func init_time_queue(tick_time=0.01, queue_length=240, data_source=parent, queue=PoolVector3Array()):
	self.tick_time = tick_time
	self.queue_length = queue_length
	self.data_source = data_source
	self.queue = queue
	for i in range(queue_length):
		queue.append(null)

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

func calculate_delta_p_in_time_range(time_ago_beginning, time_ago_end):
	pass

# Call at beginning of physics tick, BEFORE adding newest_delta_p to queue
func calculate_rolling_delta_p_sum(newest_delta_p):
	rolling_delta_p_sum += newest_delta_p - get_snapshot_x_ticks_ago(rolling_sum_ticks)
