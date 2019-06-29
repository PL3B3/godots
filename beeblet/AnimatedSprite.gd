extends AnimatedSprite

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("animation_finished", self, "on_AnimatedSprite_animation_finished")
	
func on_AnimatedSprite_animation_finished():
	if self.animation == "run":
		animation = "attack"
	else:
		animation = "run"
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
