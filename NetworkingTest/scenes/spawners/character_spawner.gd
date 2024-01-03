extends MultiplayerSpawner

var kinematic_character_scene = preload("res://scenes/movement/character_movement_kinematic_body.tscn")
var rigid_character_scene = preload("res://scenes/movement/character_movement_rigid_body_3d.tscn")
var ThirdPersonDisplayScene = preload("res://scenes/character/third_person_display.tscn")

func _ready():
	spawn_function = spawn_character

func spawn_character(data: Dictionary):
	var position = data["position"]
	var id = data["id"]
	print("Spawn id: %s. Self id: %s." % [id, multiplayer.get_unique_id()])
	var character: Node3D
	if (multiplayer.get_unique_id() != Network.SERVER_UNIQUE_ID and multiplayer.get_unique_id() != id):
		print("Spawning puppet")
		character = ThirdPersonDisplayScene.instantiate()
	else:
		character = kinematic_character_scene.instantiate()
	character.position = position
	character.name = str(id)
	return character
