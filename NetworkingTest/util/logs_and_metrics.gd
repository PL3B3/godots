extends Node

var statistics_: Dictionary = {}

func add_client_stat(stat_name, interval=10, use_diff=false):
	add_statistic(stat_name, NetworkLogMode.CLIENT_ONLY, interval, use_diff)

func add_server_stat(stat_name, interval=10, use_diff=false, display_label=null):
	add_statistic(stat_name, NetworkLogMode.SERVER_ONLY, interval, use_diff)

func add_statistic(stat_name, network_mode, interval=10, use_diff=false, display_label=null):
	var statistic = Statistics.new(stat_name, use_diff, network_mode, interval)
	statistics_[stat_name] = statistic
	add_child(statistic)
	if display_label:
		statistic.new_statistic_calculated.connect(func (stat_blurb): display_label.set_text(stat_blurb))

func add_sample(stat_name, sample):
	statistics_[stat_name].add_sample(sample)

