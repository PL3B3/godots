extends MultiplayerSpawner

func _ready():
	spawn_function = spawn_character

func spawn_character(data: Dictionary):
	var position = data["position"]
	var id = data["id"]
	var character: Node3D = load("res://scenes/character_movement_body.tscn").instantiate()
	character.position = position
	character.name = str(id)
	return character 
