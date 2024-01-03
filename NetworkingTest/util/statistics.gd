extends Node

class_name Statistics

signal new_statistic_calculated(stat_blurb: String)

const USE_DIFF = true
const RAW_VALUE = false
const DEFAULT_INTERVAL = 5.0

var statistic_name_: String
var use_diff_: bool
var network_mode_: int
var samples_: Array = []
var last_value_: Array = []
var interval_sec_: float

func _init(statistic_name: String, use_diff: bool, network_mode: int, interval_sec: float=DEFAULT_INTERVAL):
	statistic_name_ = statistic_name
	use_diff_ = use_diff
	network_mode_ = network_mode
	interval_sec_ = interval_sec

func _ready():
	var timer = Timer.new()
	timer.set_wait_time(interval_sec_)
	timer.set_one_shot(false)
	timer.timeout.connect(print_and_clear_stats)
	add_child(timer)
	timer.start()

func add_sample(raw_sample):
	if use_diff_:
		if last_value_.is_empty():
			last_value_.push_back(raw_sample)
			return
		else:
			samples_.push_back(float(raw_sample - last_value_[0]))
			last_value_[0] = raw_sample
	else:
		samples_.push_back(float(raw_sample))

func print_and_clear_stats():
	if !should_display(network_mode_):
		samples_.clear()
		return
	if samples_.is_empty():
		print("%s: cannot calculate statistics: no samples" % [statistic_name_])
		return
	samples_.sort()
	var max = samples_[-1]
	var min = samples_[0]
	var median = samples_[int(samples_.size() / 2)]
	var mean = samples_.reduce(func(accum, sample): return accum + (sample / float(samples_.size())), 0.0)
	var total_variance = samples_.reduce(func(curr_total, sample): return curr_total + pow(sample - mean, 2), 0.0)
	var std_dev = sqrt(total_variance / max(1.0, samples_.size() - 1.0))
	var stat_blurb = "%s: median: %.3f, mean: %.3f, std_dev: %.3f, min: %.3f, max: %.3f" % [statistic_name_, median, mean, std_dev, min, max]
	new_statistic_calculated.emit(stat_blurb)
	print(stat_blurb)
	samples_.clear()

func network_mode():
	return network_mode_

func should_display(network_mode):
	match network_mode:
		NetworkLogMode.CLIENT_ONLY:
			return !multiplayer.is_server()
		NetworkLogMode.SERVER_ONLY:
			return multiplayer.is_server()
		NetworkLogMode.CLIENT_AND_SERVER:
			return true
		_:
			print("%s is not a valid value of NetworkLogMode. Not displaying log or stat" % network_mode)
			return false
