extends Timer

onready var parent = get_parent()
# number of remaining times for timer to repeat
var total_iterations
var iterations

# functions to call
var body_func
var body_args
var exit_func
var exit_args
var ps_timer
var cap_time

# @param fx is the effect name to take in
# @param ps is boolean per second, to handle poison effects
func old_init_timer(time, fx, args, ps):
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

# p: time: cap time of timer
# ps: func/args: function/args to call at beginning, during, and end of timedEffect.
# 	these are optional, and inputting "" for the function name will make it do nothing
# p: repeats: times to iterate the timer
func init_timer(time, enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats):
	# stores timer function names so they can be used later by manipulator characters
	self.body_func = body_func
	self.body_args = body_args
	self.exit_func = exit_func
	self.exit_args = exit_args

	cap_time = time
	total_iterations = repeats
	iterations = repeats

	# starts timer with cap_time. timer will repeat until iterations are done
	self.start(cap_time)
	
	# calls the enter function, if present, at beginning
	if enter_func != "":
		parent.callv(enter_func, enter_args)

	self.connect("timeout", parent, body_func, body_args)
	self.connect("timeout", self, "iterate")

func iterate():
	# we check if iterations is greater than 1 instead of 0 because of the iteration math
	# Basically it allows the number of "repeats" to correspond to the number of function calls
	if iterations > 1:
		iterations -= 1
	else:
		parent.callv(exit_func, exit_args)
		stop_timer()

func stop_ps_timer():
	ps_timer.stop()
	ps_timer.queue_free()

func stop_timer():
	queue_free()

func reset_timer():
	self.start(cap_time)
	
# Rushes the timer to end time
func accelerate_timer():
	self.start(0.01)
