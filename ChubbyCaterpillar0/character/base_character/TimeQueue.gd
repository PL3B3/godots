extends Timer

# Class uses a timer and an array to create a queue of game states,
# recording a snapshot of current game per each tick_time, then pushing it
# to a queue that is tick_total in length (snapshots)
# used for lag compensation, rewind, etc.
var tick_time
var tick_total
var snapshots = []

# current_queue_head is the position of the most recent element of the queue
var ticks_since_start = 0
var current_queue_head = 0


onready var players = get_parent().players

# top level function for usage by ChubbyServer
func init_time_queue(tick_time, tick_total, varnames):
	self.tick_time = tick_time
	self.tick_total = tick_total
	self.start(tick_time)
	self.connect("timeout", self, "tick", varnames)

func take_snapshot(varnames):
	var snapshot = {}
	for player_id in players:
		for name in varnames:
			snapshot[player_id][name] = players[player_id].get(name)
	return snapshot

# adds to the queue, starting over at the head if it overflows
# updates the current_queue head
func add_to_queue(snapshot):
	current_queue_head = ticks_since_start % tick_total

	# fill the next available spot with the snapshot
	# otherwise, if we've run out of space, start over!
	if current_queue_head < tick_total:
		snapshots[current_queue_head] = snapshot
	else:
		snapshots[0] = snapshot

# to call each tick
# increments tick counter, takes and adds snapshot
func tick(varnames):
	add_to_queue(take_snapshot(varnames))
	ticks_since_start += 1

# based on a tf2 meme where the engineer does the ol' "texas turnaround" because his will
# to live has been sapped
func the_escape_plan():
	print("The engineer is no longer here")
	queue_free()

# converts this oroborous queue boi into a NORMAL ordered array
func queue_to_sorted_array():
	var sorted_array = []
	sorted_array.resize(tick_total)

	if current_queue_head == tick_total - 1:
		return snapshots
	else:
		# "shifts" the newest elements of the queue to be after the old ones
		for i in range(tick_total):
			if i < current_queue_head:
				sorted_array[i + ((tick_total - 1) - current_queue_head)] = snapshots[i]
			else:
				sorted_array[i - (current_queue_head + 1)] = snapshots[i]

	return sorted_array

# measly test function.
#func test_print():
#	tick_total = 5
#	snapshots.resize(tick_total)
#	for i in range(13):
#		add_to_queue(i)
#		ticks_since_start += 1
#		print(str(snapshots) + " current head at: " + str(current_queue_head))


