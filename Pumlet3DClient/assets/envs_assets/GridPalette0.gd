extends Spatial

var block_colors = "000000 6f6776 9a9a97 c5ccb8 8b5580 c38890 a593a5 666092 9a4f50 c28d75 7ca1c0 416aa3 8d6268 be955c 68aca9 387080 6e6962 93a167 6eaa78 557064 9d9f7f 7e9e99 5d6872 433455"

func _ready():
#	create_mesh()
	create_meshes()

func create_mesh():
	var shape = MeshInstance.new()
	shape.mesh = CubeMesh.new()
	shape.transform.origin = Vector3(3, -3, 0)
	add_child(shape)
	
	shape.set_owner(self)
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(shape)
	ResourceSaver.save("res://assets/envs_assets/ColorBlocks.tscn", packed_scene)

func create_meshes():
	var packed_scene = PackedScene.new()
	var meshlib = MeshLibrary.new()
	
	var id_counter = 0
	for xstr in block_colors.split(" "):
#		print("making shape with color " + xstr)
		var shape = MeshInstance.new()
		shape.mesh = CubeMesh.new()
		shape.mesh.size = Vector3(1, 1, 1)
		add_child(shape)
		
		var shape_material = SpatialMaterial.new()
		shape_material.albedo_color = Color(xstr)
		shape_material.metallic = 0.4
		shape_material.metallic_specular = 0.6
		shape_material.roughness = 0.8
		shape.set_surface_material(0, shape_material)
		shape.set_name(xstr)
		
		shape.create_convex_collision()
		shape.transform.origin = Vector3((id_counter / 4) * 3.0, (id_counter % 4) * 3, 0)
		
		shape.set_owner(self)
		shape.get_child(0).set_owner(self)
		shape.get_child(0).get_child(0).set_owner(self)
		
		packed_scene.pack(shape)
		packed_scene.pack(shape.get_child(0))
		packed_scene.pack(shape.get_child(0).get_child(0))
		
		meshlib.create_item(id_counter)
		meshlib.set_item_mesh(id_counter, shape)
		meshlib.set_item_shapes(id_counter, [shape.get_child(0).get_child(0), shape.get_transform()])
		
		id_counter += 1
	
#	var gridmap = GridMap.new()
#	gridmap.set_mesh_library(meshlib)
#	add_child(gridmap)
#	gridmap.set_owner(self)
#	packed_scene.pack(gridmap)
	
	packed_scene.pack(get_tree().get_current_scene())
	ResourceSaver.save("res://assets/envs_assets/ColorBlocks.tscn", packed_scene)
