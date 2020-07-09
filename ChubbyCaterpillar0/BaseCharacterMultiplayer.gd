var TimedEffect = preload("res://character/TimedEffect.tscn")

##
## general player stats
##

var speed: float = 200
var health_cap : int = 200 # defines the basic "max health" of a character, but overheal and boosts can change this
var health : int = 200
var regen: int = 0
var team := 'a'
var is_alive := true
var timed_effects = []

##
## for physics and visual
##

var gravity2 := 0 # downwards movement added per frame while airborne
var velocity = Vector2(0,0)
var rot_angle := -(PI / 2) # used to orient movement relative to ground angle

##
## tracks if an ability is on cooldown
##

# I picked an arbitrary order
# 0: mouse_ability_0
# 1: mouse_ability_1
# 2: key_ability_0
# 3: key_ability_1
# 4: key_ability_2
var ability_usable = [true, true, true, true, true]
var cooldowns = [10, 10, 10, 10, 10]
# Used to convert between ability name and its index in the ability_usable array
const ability_conversions = {
    "mouse_ability_0" : 0,
    "mouse_ability_1" : 1, 
    "key_ability_0" : 2, 
    "key_ability_1" : 3, 
    "key_ability_2" : 4
}

##
## for multiplayer
##

var player_id : int # unique network id of the player
var type := "base" 
#var object_id_counter = 0
var objects = {}


# adds a created object to the object dictionary and sets its name to its counter
# also sets the object as toplevel so it may move freely, not tied to character position
# because TCP sends commands in ORDER, the objects spawned by the same ability call 
# will have the same object_counter_id
func add_object(object, uuid):
    #var object_id_string = str(object_id_counter)
    
    #object.set_name(object_id_string)
    object.set_name(uuid)
    
    # this "unties" the object from its parent player so it may move freely
    object.set_as_toplevel(true)
    
    add_child(object)
    
    #objects[object_id_string] = object
    objects[uuid] = object
    
    #object_id_counter += 1

func set_stats(speed, health_cap, regen, xy, player_id):
    self.speed = speed
    self.health_cap = health_cap
    self.health = health_cap
    self.regen = regen
    self.player_id = player_id
    set_global_position(xy)

func add_and_return_timed_effect_exit(exit_func, exit_args, repeats):
    add_and_return_timed_effect_full("", [], "", [], exit_func, exit_args, repeats)

func add_and_return_timed_effect_body(body_func, body_args, repeats):
    add_and_return_timed_effect_full("", [], body_func, body_args, "", [], repeats)

# 1. call the ability with arguments passed in, tba at time of button press
# 2. activate cooldown timer
func use_ability_and_start_cooldown(ability_name, args):
    # converts ability name to its arbitrary number from 0-4, or null if...
    # ...the ability is just a movement
    var ability_num = ability_conversions.get(ability_name)
    
    # if the ability is an actual ability and not just movement
    if (ability_num != null):
        # call the ability
        callv(ability_name, args)
        # Puts ability on cooldown
        ability_usable[ability_num] = false
        add_and_return_timed_effect_exit("call_and_sync", ["cooldown", [ability_num]], cooldowns[ability_num])
    else:
        # simply call the movement function
        callv(ability_name, args)

# calculates and syncs position/movement
func _physics_process(delta):
    get_node("Label").set_text(str(health as int))

    get_child(1).position = get_child(0).position

    if get_slide_count() > 0:
        # get one of the collisions, it's normal, and convert it into an angle
        rot_angle = get_slide_collision(get_slide_count() - 1).get_normal().angle()

    move_and_slide(60 * delta * (velocity.rotated(rot_angle + (PI / 2)) + Vector2(0.0, gravity2)), Vector2(0.0, -1.0), false, 4, 0.9)
    
    
    if is_on_floor():
        velocity = Vector2()
        gravity2 = 0
    else:
        gravity2 += 9.8

# ESSENTIAL
func cooldown(ability_num):
    ability_usable[ability_num] = true

# ESSENTIAL
func hit(dam):
    health -= dam as int
    #send_updated_attribute(str(player_id), "health", health)
    print("Was hit")
    if not health > 0:
        die()

func die():
    print("I died")
    
    # Only in Jesus mode
    #add_and_return_timed_effect_body("ascend", [], 4)
    
    # disable collisions
    $CollisionShape2D.set_deferred("disabled", true)
    
    # make invisible
    $Sprite2D.visible = false
    is_alive = false
    add_and_return_timed_effect_exit("respawn", [], 5)

func respawn():
    set_stats_default()
    is_alive = true

func ascend():
    print("ascending")
    gravity2 = -400


func up():
    velocity.y = -1.5 * speed


func down():
    velocity.y += 0.1 * speed


func right():
    #print("right called on chubbyphantom for player:" + str(player_id))
    if velocity.x <= speed:
        velocity.x += min(speed, speed - velocity.x)
    else:
        velocity.x = speed


func left():
    if velocity.x >= -speed:
        velocity.x -= min(speed, velocity.x + speed)
    else:
        velocity.x = -speed

func mouse_ability_0(mouse_pos, ability_uuid):
    pass

func mouse_ability_1(mouse_pos, ability_uuid):
    pass

func key_ability_0(ability_uuid):
    print("key_ability_0 activated on player: " + str(player_id))
    pass

func key_ability_1(ability_uuid):
    print("yohoho")
    pass

func key_ability_2(ability_uuid):
    pass