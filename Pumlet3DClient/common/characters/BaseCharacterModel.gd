extends Spatial

onready var outline = $Outline

func set_outline_color(new_color: Color):
	outline.material_override.albedo_color = new_color
