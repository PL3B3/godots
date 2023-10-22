extends MultiplayerSpawner

@onready var kinematic_character_scene = preload("res://scenes/character_movement_body.tscn")
@onready var rigid_character_scene = preload("res://scenes/character_movement_rigid_body_3d.tscn")

func _ready():
	spawn_function = spawn_character

func spawn_character(data: Dictionary):
	var position = data["position"]
	var id = data["id"]
	var character: Node3D = rigid_character_scene.instantiate()
	character.position = position
	character.name = str(id)
	return character 
