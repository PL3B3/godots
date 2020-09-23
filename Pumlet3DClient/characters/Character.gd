extends "res://common/characters/BaseCharacter.gd"

func call_and_return(method_name: String, args):
	callv(method_name, args)
	return [method_name, args]

func handle_query_input(event: InputEvent):
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cumulative_rot_x -= event.relative.x * mouse_sensitivity
		cumulative_rot_y = clamp(
			cumulative_rot_y - (event.relative.y * mouse_sensitivity),
			-90,
			90)
		return call_and_return("set_camera_rotation", [cumulative_rot_x, cumulative_rot_y])
	
	elif event.is_action_pressed("toggle_mouse_mode"):
		var new_mouse_mode
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			new_mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			new_mouse_mode = Input.MOUSE_MODE_CAPTURED
		return call_and_return("toggle_mouse_mode", [new_mouse_mode])
	
	elif event.is_action_pressed("teleport"):
		return call_and_return("teleport", [])
	
	elif (event.is_action_pressed("jump") and 
		jumps_left > 0 and 
		ticks_since_grounded < jump_tick_limit):
		return call_and_return("jump", [])
	
	elif event.is_action_pressed("toggle_flashlight"):
		var turn_light_on = not flashlight.is_visible_in_tree()
		return call_and_return("toggle_flashlight", [turn_light_on])
	
	elif event.is_action_pressed("primary_action"):
		return call_and_return("primary_action", [[camera.get_global_transform()]])
	
	elif event.is_action_pressed("secondary_action"):
		return call_and_return("secondary_action", [[camera.get_global_transform()]])
	
	elif event.is_action_pressed("tertiary_action"):
		return call_and_return("tertiary_action", [[camera.get_global_transform()]])
	
	else:
		return []

func handle_poll_input():
	var direction_num = DIRECTION.STOP
	var z_dir = 0
	var x_dir = 0
	
	if Input.is_action_pressed("move_forwards"):
		z_dir += 1
	if Input.is_action_pressed("move_backwards"):
		z_dir -= 1
	if Input.is_action_pressed("move_left"):
		x_dir -= 1
	if Input.is_action_pressed("move_right"):
		x_dir += 1
	
	if z_dir == 1:
		if x_dir == 0:
			direction_num = DIRECTION.NORTH
		elif x_dir == 1:
			direction_num = DIRECTION.NORTHEAST
		elif x_dir == -1:
			direction_num = DIRECTION.NORTHWEST
	elif z_dir == -1:
		if x_dir == 0:
			direction_num = DIRECTION.SOUTH
		elif x_dir == 1:
			direction_num = DIRECTION.SOUTHEAST
		elif x_dir == -1:
			direction_num = DIRECTION.SOUTHWEST
	elif z_dir == 0:
		if x_dir == 1:
			direction_num = DIRECTION.EAST
		elif x_dir == -1:
			direction_num = DIRECTION.WEST
		else:
			direction_num = DIRECTION.STOP
	
	return call_and_return("set_direction", [direction_num])
