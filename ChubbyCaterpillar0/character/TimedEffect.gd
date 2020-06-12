extends Timer

##
## Object representing a status effect on a player
## It functions as a one-second timer which repeats for a specified number of times
## It may call an effect on the player upon creation, upon every repeat, and upon stopping
##

onready var parent = get_parent()

# number of remaining times for timer to repeat
var max_iterations
var current_iterations

# used by DK to "accelerate time"

# functions to call
var enter_func
var enter_args
var body_func
var body_args
var exit_func
var exit_args

# deprecated variables for old timer
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

# updates this timedeffect based on latest info from server
func update(updated_iterations: int) -> void:
	current_iterations = updated_iterations

	# starts the next 1-second timer
	self.start(1)


# p: time: cap time of timer
# ps: func/args: function/args to call at beginning, during, and end of timedEffect.
# 	these are optional, and inputting "" for the function name will make it do nothing
# p: repeats: times to iterate the timer
func init_timer(time, enter_func, enter_args, body_func, body_args, exit_func, exit_args, repeats):
	# stores timer function names so they can be used later by manipulator characters
	self.enter_func = enter_func
	self.enter_args = enter_args
	self.body_func = body_func
	self.body_args = body_args
	self.exit_func = exit_func
	self.exit_args = exit_args
	
	max_iterations = repeats
	current_iterations = repeats

	# initiates this object as a one second timer. timer will repeat until iterations are done
	self.start(1)
	
	# calls the enter function, if present, at beginning
	if enter_func != "":
		parent.callv(enter_func, enter_args)
	
	# connects the iteration function to the timeout
	self.connect("timeout", self, "iterate")

# called every second while timedEffect is active
func iterate():
	# removes timer if player is dead
	if parent.is_alive == false:
		stop_timer()

	# we check if iterations is greater than 1 instead of 0 because of the iteration math
	# Basically it allows the number of "repeats" to correspond to the number of function calls
	if current_iterations > 1:
		current_iterations -= 1
		
		# call the body function if it exists
		if body_func != "":
			parent.callv(body_func, body_args)
	else:
		# timer has reached its end
		# call the exit function if present
		if exit_func != "":
			parent.callv(exit_func, exit_args)
		
		stop_timer()

#func stop_ps_timer():
#	ps_timer.stop()
#	ps_timer.queue_free()

func stop_timer():
	self.stop()
	queue_free()

func reset_timer():
	current_iterations = max_iterations
