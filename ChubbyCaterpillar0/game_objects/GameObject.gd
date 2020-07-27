extends KinematicBody2D

##
## Base class for synced objects
##

onready var parent = get_parent()

var counter_id
var uuid

# self-explanatory
func remove_from_parent_and_free() -> void:
	parent.objects.erase(str(counter_id))
	queue_free()


# fast-forwards the object a specified amount of time
func advance(time_to_advance: float) -> void:
	pass
