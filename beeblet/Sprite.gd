extends Sprite

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const pi = 3.1415

var timer

# Called when the node enters the scene tree for the first time.
func _ready():
	timer = Timer.new()
	timer.connect("timeout", self, "tick")
	add_child(timer)
	timer.wait_time = 0.2
	timer.start()
	
func tick():
	if self.frame < 9:
		self.frame += 1
	else:
		self.frame = 0	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass