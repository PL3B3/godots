extends Camera2D


onready var Interpolator = get_node("/root/ChubbyServer/Interpolator")


var catch_up_rate := 0.02 # how quick camera catches up to player position + velocity
var scouting_distance_x := 0.15 # how far ahead camera looks in direction of velocity_x
var scouting_distance_y := 0.05 # how far ahead camera looks in direction of velocity_y

# Called when the node enters the scene tree for the first time.
func _ready():
	make_current()
	$TeamMenu.connect("mouse_entered", self, "team_menu_entered")

# Alerts parent player that mouse is in team menu
func team_menu_entered():
	pass

# Alerts
func team_menu_exited():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var parent = get_parent()
	var new_transform = get_transform()
	if ("velocity" in parent): # if parent is player
		var target = Vector2(scouting_distance_x * parent.velocity.x, scouting_distance_y * parent.velocity.y)
		# the camera should ease towards where player is going
		new_transform[2] += catch_up_rate * (target - transform[2])
	# Interpolator for smooth movement
	Interpolator.interpolate_property(self, "transform", get_transform(), new_transform, delta, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
