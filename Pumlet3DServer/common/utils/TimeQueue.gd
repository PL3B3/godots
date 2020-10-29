extends Timer

# Circular queue backed by an array
# Keeps a rolling record of data for game entities
var tick_time
var queue_length
var varnames
var queue

# current_queue_tail is where the next element is added
var ticks_since_start = 0
var current_queue_tail = 0

onready var parent = get_parent()
var data_source

func init_time_queue(tick_time=0.016666666666, queue_length=120, data_source=parent, queue=[]):
	self.tick_time = tick_time
	self.queue_length = queue_length
	self.data_source = data_source
	for i in range(queue_length):
		queue.append(null)
	self.queue = queue
	self.start(tick_time)
	self.connect("timeout", self, "add_snapshot")

func add_snapshot():
	var snapshot = data_source.take_snapshot()
	add_to_queue(snapshot)

func add_to_queue(snapshot):
	# if we've run out of space, start over!
	if not current_queue_tail < queue_length:
		current_queue_tail = 0
	queue.set(current_queue_tail, snapshot)
	current_queue_tail += 1
	ticks_since_start += 1

# returns null for invalid timestamps
func get_snapshot_x_seconds_ago(time_ago):
	var ticks_ago : int
	if time_ago < tick_time:
		ticks_ago = 1
	else:
		ticks_ago = int(time_ago / tick_time)
	
	return get_snapshot_x_ticks_ago(ticks_ago)

func get_snapshot_x_ticks_ago(ticks_ago):
	if ticks_ago >= min(queue_length, ticks_since_start):
		print("Specified access time too far in the past")
		return null
	
	var index = current_queue_tail - ticks_ago
	return queue[index]

# converts queue into a normal array
func queue_to_flat_array():
	var flat_array = []
	flat_array.resize(queue_length)
	
	if current_queue_tail == queue_length - 1:
		return queue
	else:
		# "shifts" the newest elements of the queue to be after the old ones
		for i in range(queue_length):
			if i < current_queue_tail:
				flat_array[i + ((queue_length - 1) - current_queue_tail)] = queue[i]
			else:
				flat_array[i - (current_queue_tail + 1)] = queue[i]
	
	return flat_array
