extends Node

const SERVER = true
const CLIENT = false
var goodwater_map = preload("res://Common/map/Goodwater.tscn")

func _on_ButtonServer_pressed():
	Network.start_network(SERVER)
	get_tree().change_scene_to(goodwater_map)

func _on_ButtonClient_pressed():
	Network.start_network(CLIENT)
	get_tree().change_scene_to(goodwater_map)
