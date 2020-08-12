extends Area2D

onready var parent = get_parent()

signal mask_set()

func _ready():
	self.connect("body_entered", self, "_on_body_entered")
	set_collision_mask(parent.get_collision_mask())
	# Removes pickups and environment from mask (don't hit healthpacks!)
	#set_collision_mask_bit(7, false)
	#set_collision_mask_bit(8, false)
	emit_signal("mask_set")
	print("mask_set")

func _on_body_entered(body: Node):
	print("A bodice has entered")

func _physics_process(delta):
	print("hello am physics")
	print(get_overlapping_bodies())
	for body in get_overlapping_bodies():
		print("hitting body: " + str(body))
		if body.has_method("hit"):
			# Calculates damage based on distance from center of area2d
			body.emit_signal("method_called", "hit", [20 * (2 - (position.distance_to(body.position) \
				/ get_node("AOEShape").get_shape().get_radius()))])
