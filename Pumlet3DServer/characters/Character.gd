extends "res://common/characters/BaseCharacter.gd"

signal send_origin_update_to_my_client(id_to_update, new_origin)
signal send_velocity_update_to_my_client(id_to_update, new_vel)

var max_sync_period = 0.1 # 10 times a second
var default_sync_period = 0.05 # 20 times a second
var min_sync_period = 0.025 # 40 times a second

var focus_sync_change_factor = 1.2 # how fast to increase sync rate for focused
var peripheral_sync_change_factor = 1
var ignored_sync_change_factor = 0.98

var delta_origin_send_threshold = 0.5 # send if pos-oldpos > this * sync period
var delta_velocity_send_threshold = 0.5

 # id : [last_sent_orig, last_send_vel, timer queries id for updates on timeout]
var sync_query_timer_dict = {}

func _ready():
	physics_enabled = true

func add_player_to_sync_dict(new_player_id):
	var new_player = server.players[new_player_id]
	
	var sync_timer = Timer.new()
	sync_timer.set_name("st_" + name + "_" + str(new_player_id))
	add_child(sync_timer)
	sync_timer.connect("timeout", self, "query_for_sync", [new_player_id, sync_timer])
	sync_timer.start(default_sync_period)
	
	sync_query_timer_dict[new_player_id] = [
		Vector3(),
		Vector3(),
		sync_timer]

func remove_player_from_sync_dict(departing_player_id):
	var sync_entry = sync_query_timer_dict[departing_player_id]
	sync_entry[2].queue_free()
	sync_query_timer_dict.erase(departing_player_id)

func query_for_sync(player_id_to_query, sync_timer):
	var player_to_query = server.players.get(player_id_to_query)
	if not player_to_query == null:
		var sync_entry = sync_query_timer_dict[player_id_to_query]
		
		var query_velocity = player_to_query.velocity
		var query_origin = player_to_query.get_global_transform().origin
		var looking_at_factor = (
			(query_origin - 
			get_global_transform().origin).normalized().dot(
				-1 * camera.transform.basis.z))
		
		var sync_period = sync_timer.get_wait_time()
		var new_wait_scale
		if looking_at_factor > 0: # within 90 deg
			new_wait_scale = focus_sync_change_factor
		elif looking_at_factor > -0.5: # within 120 deg
			new_wait_scale = peripheral_sync_change_factor
		else:
			new_wait_scale = ignored_sync_change_factor
		sync_timer.start(
			clamp(
				sync_period * 
				new_wait_scale, 
				min_sync_period, 
				max_sync_period))
		
		if (
			(query_origin - sync_entry[0]).length() > 
			delta_origin_send_threshold * sync_period):
			emit_signal(
				"send_origin_update_to_my_client", 
				player_id_to_query, 
				query_origin)
			sync_entry[0] = query_origin
		
		if (
			(query_velocity - sync_entry[1]).length() >
			delta_velocity_send_threshold * sync_period):
			emit_signal(
				"send_velocity_update_to_my_client", 
				player_id_to_query, 
				query_velocity)
			sync_entry[1] = query_velocity
		
	#	print("%s queries %s %d times a second" % [
	#		name,
	#		player_id_to_query,
	#		int(1 / sync_timer.get_wait_time())])
		pass

