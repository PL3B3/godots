extends Spatial

onready var outline = $Outline

func _ready():
	initialize_outline()

func initialize_outline():
	var outline_material = SpatialMaterial.new()
	outline_material.flags_unshaded = true
	outline_material.flags_vertex_lighting = true
	outline.material_override = outline_material

func set_outline_color(new_color: Color):
	outline.material_override.albedo_color = new_color
