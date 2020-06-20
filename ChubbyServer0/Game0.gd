extends Node2D

var character = preload("res://character/base_character/ChubbyPhantom.tscn")
var map = preload("res://maps/Map0.tscn")
#var chubby = preload("res://ChubbyServer.tscn")

func _ready():
#	var character_0 = character.instance()
#	character_0.set_stats(200, 200, 200, 200)
	var map_0 = map.instance()
#	ChubbyServer.physics_processing = true
#	ChubbyServer.add_player(20, "base")
#	add_child(character_0)
	add_child(map_0)