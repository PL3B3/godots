extends "res://FiredProjectile.gd"

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	bullet_life = 10
	gravity = 10

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass