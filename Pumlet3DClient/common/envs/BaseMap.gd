extends Spatial

onready var grid_map = $GridMap

func get_ground_name(player_position: Vector3) -> String:
	var ground_tile_name = grid_map.mesh_library.get_item_name(grid_map.get_cell_id_under_player(player_position))
	print(ground_tile_name)
	return(ground_tile_name)
