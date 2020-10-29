extends GridMap

# -----------------------------------------------------------------------Utility
func get_cell_id_under_player(player_position: Vector3) -> int:
	return get_cell_id_at_position(player_position - Vector3(0, 2.5, 0))

func get_cell_id_at_position(position: Vector3) -> int:
	var grid_position = world_to_map(position - Vector3(0, 2.5, 0))
	return get_cell_item(grid_position.x, grid_position.y, grid_position.z)
