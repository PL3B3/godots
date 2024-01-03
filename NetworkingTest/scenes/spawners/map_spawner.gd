extends MultiplayerSpawner


func _ready():
	spawn_function = func(_data): return load("res://scenes/large_test_map.tscn").instantiate()
