extends Mover

class_name Gamer

onready var target = preload("res://Common/game/Target.tscn")

enum PHANTOM_STATE {
	PROCESSED,
	POSITION,
	VELOCITY,
	LOOK,
	HEALTH}

enum STATE {
	POSITION,
	VELOCITY, # slid vel at end of previous frame
	HEALTH,
	FAST_CHARGE_TIME_LEFT,
	SLOW_CHARGE_TIME_LEFT,
	ULT_CHARGE}

# ----------------------------------------------------------------Gamer settings
var base_health := 100 # limit to how much healing items can heal you
var meat_health := 150 # highest persistent health
var over_health := 200 # decays to meat_health
var buff_decay_rate := 5 # amount buff to decay every 0.5 seconds

var recharge_rate := 6 # after this many ticks, we decrease the "time" left by 1
var fast_recharge_time := 85
var slow_recharge_time := 255

var ult_charge_max := 250 

# --------------------------------------------------------------------Gamer vars
var state_slice = []

var fast_recharge_ticks_left := 0 # how many phys ticks b4 next time decrease
var slow_recharge_ticks_left := 0 # set=recharge_rate on ability press


# ----------------------------------------------------------------Input settings
var mouse_sensitivity := 0.04
var jump_try_ticks_default := 3

# --------------------------------------------------------------------Input vars
var jump_try_ticks_remaining := 0

# ------------------------------------------------------------------Network vars
var state_buffer:PoolBuffer


# ---------------------------------------------------------------Experiment Vars
var raycast_this_physics_frame = false
var target_position = Vector3(10.0, 5.0, -15.0)
var test_target
var targets = []

func _ready():
	init_state_recording()

	Network.client_gamer = self

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func init_state_recording():
	state_slice = []
	state_slice.resize(STATE.size())
	state_slice[STATE.POSITION] = transform.origin
	state_slice[STATE.VELOCITY] = Vector3()
	state_slice[STATE.HEALTH] = base_health
	state_slice[STATE.ULT_CHARGE] = 0
	state_slice[STATE.SLOW_CHARGE_TIME_LEFT] = 0
	state_slice[STATE.FAST_CHARGE_TIME_LEFT] = 0

	var state_stubs = []
	state_stubs.resize(STATE.size())
	state_stubs[STATE.POSITION] = PoolVector3Array()
	state_stubs[STATE.VELOCITY] = PoolVector3Array()
	state_stubs[STATE.HEALTH] = PoolByteArray()
	state_stubs[STATE.FAST_CHARGE_TIME_LEFT] = PoolByteArray()
	state_stubs[STATE.SLOW_CHARGE_TIME_LEFT] = PoolByteArray()
	state_stubs[STATE.ULT_CHARGE] = PoolByteArray()
	state_buffer = PoolBuffer.new(state_stubs)

func setup_test_targets():
	"""
	for i in range(10):
			var target_to_shoot = target.instance()
			target_to_shoot.transform.origin = target_position
			targets.push_back(target_to_shoot)
			get_tree().get_root().call_deferred("add_child", target_to_shoot)
	"""
	test_target = target.instance()
	test_target.transform.origin = target_position
	get_tree().get_root().call_deferred("add_child", test_target)

func _unhandled_input(event):
	if event.is_action_pressed("click"):
		pass
		# test_target.transform.origin = Vector3(-10.0, 2.0, 4.0)
		# test_target.force_update_transform()
		# raycast_this_physics_frame = true
		
	if (event is InputEventMouseMotion 
		&& Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		var yaw_delta = -event.relative.x * mouse_sensitivity
		var pitch_delta = event.relative.y * mouse_sensitivity
		yaw += yaw_delta
		yaw = deg_to_deg360(yaw)
		
		rotation_degrees.y = yaw
		orthonormalize()
		pitch = clamp(
			pitch - pitch_delta, 
			-90.0, 
			90.0
			)
		camera.rotation_degrees.x = pitch
		camera.orthonormalize()
		
	elif event.is_action_pressed("toggle_mouse_mode"):
		var new_mouse_mode
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			new_mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			new_mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(new_mouse_mode)
		
	elif event.is_action_pressed("jump"):
		# try a jump for next jump_try_ticks_default ticks
		jump_try_ticks_remaining = jump_try_ticks_default

func _physics_process(delta):
	record_move()

	record_state()

	handle_networking()

	calculate_movement(delta)

	apply_movement()

	get_next_move()

	get_next_state()

func handle_raycast():
	if raycast_this_physics_frame:
		for i in range(1):
			var space_state = get_world().direct_space_state
			var result = space_state.intersect_ray(
				Vector3(10.0, 2.0, 3.0), 
				Vector3(-10.0, 2.0, 4.0))
			if result and is_instance_valid(result.collider):
				print(result.collider)
		# for i in range(targets.size()):
		# 	var target_to_shoot = targets[i]
		# 	target_to_shoot.transform.origin = Vector3(-10.0, 2.0, i * -4.0)
		# 	target_to_shoot.force_update_transform()
		# 	var result = space_state.intersect_ray(
		# 		Vector3(10.0, 2.0, 3.0), 
		# 		target_to_shoot.transform.origin)
		# 	if result and is_instance_valid(result.collider):
		# 		print(result.collider)
		# 		#result.collider.queue_free()
		# 	target_to_shoot.transform.origin = target_position
		raycast_this_physics_frame = false

func record_move():
	move_buffer.write(
		move_slice,
		Network.physics_tick_id)

func get_next_move(): # get move to process this phys frame
	# --------for calc look_delta
	var last_look = move_slice[MOVE.LOOK]
	
	move_slice[MOVE.PROCESSED] = 1
	
	if jump_try_ticks_remaining > 0:
		move_slice[MOVE.JUMP] = 1
		jump_try_ticks_remaining -= 1
	else:
		move_slice[MOVE.JUMP] = 0

	# --------cardinal direction
	move_slice[MOVE.X_DIR] = 0
	move_slice[MOVE.Z_DIR] = 0
	
	if Input.is_action_pressed("move_left"):
		move_slice[MOVE.X_DIR] -= 1
	if Input.is_action_pressed("move_right"):
		move_slice[MOVE.X_DIR] += 1
	if Input.is_action_pressed("move_forward"):
		move_slice[MOVE.Z_DIR] += 1
	if Input.is_action_pressed("move_backward"):
		move_slice[MOVE.Z_DIR] -= 1
	
	move_slice[MOVE.LOOK] = Vector2(yaw, pitch)
	
	move_slice[MOVE.LOOK_DELTA] = int(
		last_look.is_equal_approx(
			move_slice[MOVE.LOOK]))

func record_state(): # state @start of phys frame, before move/other changes
	state_buffer.write(
		state_slice,
		Network.physics_tick_id)

func get_next_state():
	var fast_time_left = state_slice[STATE.FAST_CHARGE_TIME_LEFT] 
	if fast_time_left > 0:
		if fast_recharge_ticks_left == 0:
			state_slice[STATE.FAST_CHARGE_TIME_LEFT] -= 1
			fast_recharge_ticks_left = recharge_rate
		else:
			fast_recharge_ticks_left -= 1

	var slow_time_left = state_slice[STATE.SLOW_CHARGE_TIME_LEFT]
	if slow_time_left > 0:
		if slow_recharge_ticks_left == 0:
			state_slice[STATE.SLOW_CHARGE_TIME_LEFT] -= 1
			slow_recharge_ticks_left = recharge_rate
		else:
			slow_recharge_ticks_left -= 1

	state_slice[STATE.POSITION] = transform.origin

	state_slice[STATE.VELOCITY] = velocity



func handle_networking():
	pass
