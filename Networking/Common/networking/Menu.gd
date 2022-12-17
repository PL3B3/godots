extends Node

var goodwater_map = preload("res://Common/map/Goodwater.tscn")

func _on_ButtonServer_pressed():
	Network.start_network(true)
	get_tree().change_scene_to(goodwater_map)

func _on_ButtonClient_pressed():
	Network.start_network(false)
	get_tree().change_scene_to(goodwater_map)
