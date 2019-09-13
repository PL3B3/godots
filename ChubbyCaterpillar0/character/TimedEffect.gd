extends Timer

onready var parent = get_parent()
var ps_timer
var cap_time

# @param fx is the effect name to take in
# @param ps is boolean per second, to handle poison effects
func init_timer(time, fx, args, ps):
	cap_time = time
	self.set_one_shot(true)
	self.start(cap_time)
	
	if not ps:
		self.connect("timeout", parent, fx, args)
		self.connect("timeout", self, "stop_timer")
		print(parent)
	else:
		# important note, the ps timer only runs for effect time - 1 because the effect timeout cuts out the last ps_timer timeout
		ps_timer = Timer.new()
		ps_timer.start(1)
		add_child(ps_timer)
		ps_timer.connect("timeout", parent, fx, args)
		
		self.connect("timeout", self, "stop_ps_timer")

func stop_ps_timer():
	ps_timer.stop()
	ps_timer.queue_free()

func stop_timer():
	queue_free()

func reset_timer():
	self.start(cap_time)
	
func accelerate_timer():
	self.start(0.01)
