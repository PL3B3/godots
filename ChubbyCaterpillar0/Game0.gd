extends Node2D

var character = preload("res://character/Character0.tscn")
var map = preload("res://maps/Map0.tscn")

func _ready():
	var character_0 = character.instance()
	character_0.set_stats(200, 200, 200, 200)
	var map_0 = map.instance()
	add_child(character_0)
	add_child(map_0)
