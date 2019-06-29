extends Node

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var x = range(10)

const cheb = 10

export(int, FLAGS, "Fire", "Water", "Earth", "Wind") var spell_elements = 0
export(Array, int, "Red", "Green", "Blue") var enums = [2, 1, 0]

# Called when the node enters the scene tree for the first time.
func _ready():
	var squareToTen = Array()
	for i in range(10):
		squareToTen.append(i * i)
	print(squareToTen)
	print("wow")
