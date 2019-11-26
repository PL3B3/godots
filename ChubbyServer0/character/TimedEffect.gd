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
		print(parent)
	else:
		# important note, the ps timer only runs for effect time - 1 because the effect timeout cuts out the last ps_timer timeout
		ps_timer = Timer.new()
		ps_timer.start(1)
		add_child(ps_timer)
		ps_timer.connect("timeout", parent, fx, args)
		
		self.connect("timeout", self, "stop_ps_timer")

"""
@param time: total effect time
@param fx:
	0: parent function to call upon timer start
	1: parent function to call on end
	2: parent function to call on interval
@param fx_args: 
	0: args for fx 0
	1: args for fx 1
	2: args for fx 2
@param interval
	interval at which to repeat interval event
	0 indicates no interval
"""
func init_timer_2(time, fx, args, ps):
	cap_time = time
	self.set_one_shot(true)
	self.start(cap_time)
	
	if not ps:
		self.connect("timeout", parent, fx, args)
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

func reset_timer():
	self.start(cap_time)
	
func accelerate_timer():
	self.start(0.01)
