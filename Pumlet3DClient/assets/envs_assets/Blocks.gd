extends Spatial

onready var camera_origin = $Spatial
onready var camera = $Spatial/Camera

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	create_meshlib()

func create_meshlib():
	var meshlib = MeshLibrary.new()
	
	var id_counter = 0
	for shape in get_children():
		if shape.name != "Spatial":
			var shape_material = SpatialMaterial.new()
			shape_material.albedo_texture = load("res://envs/envs_assets/Textures/" + shape.name + ".png")
			shape.set_surface_material(0, shape_material)
			shape.set_scale(Vector3(0.05, 0.05, 0.05))
			shape.create_convex_collision()
			meshlib.create_item(id_counter)
			meshlib.set_item_mesh(id_counter, shape)
			print(shape.get_children())
			meshlib.set_item_shapes(id_counter, [shape.get_child(0).get_child(0), shape.get_transform()])
			id_counter += 1
	
	var gridmap = GridMap.new()
	gridmap.set_mesh_library(meshlib)
	
	add_child(gridmap)
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(get_tree().get_current_scene())
	ResourceSaver.save("res://envs/envs_assets/TexturedBlocks.tscn", packed_scene)

export var mouse_sensitivity = 0.1
var camera_x_rotation = 0

func _input(event):
	if event is InputEventMouseMotion:
		camera_origin.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		var x_delta = event.relative.y * mouse_sensitivity
		if camera_x_rotation + x_delta > -90 and camera_x_rotation + x_delta < 90: 
			camera.rotate_x(deg2rad(-x_delta))
			camera_x_rotation += x_delta
