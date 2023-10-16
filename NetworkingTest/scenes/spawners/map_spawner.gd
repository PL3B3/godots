extends MultiplayerSpawner


func _ready():
	spawn_function = func(_data): return load("res://scenes/map.tscn").instantiate()
