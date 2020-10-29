extends Spatial

var outline_size = 0.03
var pack_destination = "res://testing/GeneratedBlocks.tscn"
var block_colors = "000000 6f6776 9a9a97 c5ccb8 8b5580 c38890 a593a5 666092 9a4f50 c28d75 7ca1c0 416aa3 8d6268 be955c 68aca9 387080 6e6962 93a167 6eaa78 557064 9d9f7f 7e9e99 5d6872 433455"

var outline_material = preload("res://testing/OutlineMaterial.tres")

func _ready():
	generate_and_pack_meshes()

func generate_and_pack_meshes():
	var packed_scene = PackedScene.new()
	
	var id_counter = 0
	for xstr in block_colors.split(" "):
		var shape = make_mesh(xstr)
		shape.create_convex_collision()
		shape.transform.origin = Vector3((id_counter / 4) * 3, (id_counter % 4) * 3, 0)
		shape.set_name(xstr)
		
		add_child(shape)
		shape.set_owner(self)
		shape.get_child(0).set_owner(self)
		shape.get_child(0).get_child(0).set_owner(self)
		
		packed_scene.pack(shape)
		packed_scene.pack(shape.get_child(0))
		packed_scene.pack(shape.get_child(0).get_child(0))
		
		id_counter += 1
	
	packed_scene.pack(get_tree().get_current_scene())
	ResourceSaver.save(pack_destination, packed_scene)


func make_mesh(xstr) -> Mesh:
	var shape = MeshInstance.new()
	
	var arr_mesh = ArrayMesh.new()
#	var arrays = []
#	arrays.resize(ArrayMesh.ARRAY_MAX)
	
	var cube = CubeMesh.new()
	cube.size = Vector3(1, 1, 1)
	var outline = cube.create_outline(outline_size)
	
	add_surfaces_to_array_mesh(arr_mesh, cube)
	add_surfaces_to_array_mesh(arr_mesh, outline)
	
	var m = MeshInstance.new()
	shape.mesh = arr_mesh
	
	shape.set_surface_material(0, create_material(xstr))
	shape.set_surface_material(1, outline_material)
	
	return shape


func create_material(xstr):
	var shape_material = SpatialMaterial.new()
	shape_material.albedo_color = Color(xstr)
	shape_material.metallic = 0.3
	shape_material.metallic_specular = 0.3
	shape_material.roughness = 1.0
	
	return shape_material


func add_surfaces_to_array_mesh(arr_mesh, from_mesh):
	for surface_index in range(from_mesh.get_surface_count()):
		arr_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, 
			from_mesh.surface_get_arrays(surface_index))
			# add this as the third parameter to the above method if using 
			# blend shapes:
#			from_mesh.surface_get_blend_shape_arrays(surface_index)
