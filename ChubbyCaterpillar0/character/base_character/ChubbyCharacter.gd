extends "res://character/base_character/BaseCharacterMultiplayer.gd"

# 扭曲树

# base class for multiplayer-oriented character


##
## Preloaded resources
##

onready var client = get_node("/root/ChubbyServer")
onready var uuid_generator = client.client_uuid_generator

var character_under_my_control = false # Sets player character

# for debugging: this makes only network master able to control this character
# and sets global position to 0,0
func _ready():
	print("This is the character base class. Prepare muffin.")
	character_under_my_control = is_network_master()

func _unhandled_input(event):
	# Detect up/down/left/right keystate and only move when pressed.
	if character_under_my_control && is_alive:
		if event is InputEventKey:
			if event.pressed:
				#or Input.is_key_pressed(KEY_W)
				if event.scancode == KEY_W:
					print("W pressed")
					$FloorScan.enabled = true
					if is_on_floor():
						use_ability_and_notify_server_and_start_cooldown("up", [])
					$FloorScan.set_enabled(false)
				if event.scancode == KEY_D && !event.echo:
					use_ability_and_notify_server_and_start_cooldown("right", [])
				if event.scancode == KEY_A && !event.echo:
					use_ability_and_notify_server_and_start_cooldown("left", [])
				if event.scancode == KEY_S:
					use_ability_and_notify_server_and_start_cooldown("down", [])
				if event.scancode == KEY_E && ability_usable[2]:
					use_ability_and_notify_server_and_start_cooldown("key_ability_0", [])
				# key_ability_1
				if event.scancode == KEY_R && ability_usable[3]:
					use_ability_and_notify_server_and_start_cooldown("key_ability_1", [])
				# key_ability_2
				if event.scancode == KEY_C && ability_usable[4]:
					use_ability_and_notify_server_and_start_cooldown("key_ability_2", [])
			if !event.pressed:
				if event.scancode == KEY_D:
					# reverse the momentum change
					use_ability_and_notify_server_and_start_cooldown("left", [])
				if event.scancode == KEY_A:
					# reverse the momentum change
					use_ability_and_notify_server_and_start_cooldown("right", [])
	if event is InputEventMouseButton:
		if event.pressed:
			# mouse_ability_0
			if event.button_index == BUTTON_LEFT && ability_usable[0]:
				use_ability_and_notify_server_and_start_cooldown("mouse_ability_0", [get_global_mouse_position()])
			# mouse_ability_1
			if event.button_index == BUTTON_RIGHT && ability_usable[1]:
				use_ability_and_notify_server_and_start_cooldown("mouse_ability_1", [get_global_mouse_position()])

var counter = 0
# gets input
func _physics_process(delta):
	counter += 1
	if counter % 83 == 0:
		print(position)

# 1. call the ability with arguments passed in, tba at time of button press
# 2. tell the server the command given
# 3. activate cooldown timer
# 4. attaches a uuid to this specific command (at the end of the args array) to be used for syncing purposes
func use_ability_and_notify_server_and_start_cooldown(ability_name, args):
	# converts ability name to its enumeration
	var ability_num = ability_conversions.get(ability_name)
	
	# checks to see if the "ability" is an actual ability or just movement	
	if (ability_num != null): # it's an ability
		# generates a uuid to track the command, adds it to args
		var ability_uuid = uuid_generator.v4()
		args.push_back(ability_uuid)
		
		# calls the ability
		callv(ability_name, args)
		
		# for debugging
		# print(str(player_id) + " activated ability: " + ability_name)
		
		# Tells server our player did the action and the arguments used
		if not client.offline:
			client.send_player_rpc(player_id, ability_name, args)
		
		# Puts ability on cooldown
		if not client.offline:
			ability_usable[ability_num] = false
			add_and_return_timed_effect_body("notify_cooldown", [ability_name], cooldowns[ability_num])
	else: # it's a movement
		callv(ability_name, args)
		# use udp b/c movement isn't essential
		if not client.offline:
			client.send_player_rpc_unreliable(player_id, ability_name, args)


# notifies that an ability is on cooldown each second
func notify_cooldown(ability_name: String) -> void:
	print(ability_name + " is on cooldown")