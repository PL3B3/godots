extends Node

class_name Statistics

const USE_DIFF = true
const RAW_VALUE = false
const DEFAULT_INTERVAL = 5.0

var statistic_name_: String
var use_diff_: bool
var samples_: Array = []
var last_value_: Array = []
var interval_sec_: float

func _init(statistic_name: String, use_diff: bool, interval_sec: float=DEFAULT_INTERVAL):
	statistic_name_ = statistic_name
	use_diff_ = use_diff
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
	if samples_.is_empty():
		print("%s: cannot calculate statistics: no samples" % [statistic_name_])
		return
	samples_.sort()
	var max = samples_[-1]
	var median = samples_[int(samples_.size() / 2)]
	var mean = samples_.reduce(func(accum, sample): return accum + (sample / float(samples_.size())), 0.0)
	var total_variance = samples_.reduce(func(curr_total, sample): return curr_total + pow(sample - mean, 2), 0.0)
	var std_dev = sqrt(total_variance / max(1.0, samples_.size() - 1.0))
	var stat_blurb = "%s: median: %.3f, mean: %.3f, std_dev: %.3f, max: %.3f" % [statistic_name_, median, mean, std_dev, max]
	print(stat_blurb)
	samples_.clear()
