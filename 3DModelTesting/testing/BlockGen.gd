extends Spatial

var outline_size = 0.05
var pack_destination = "res://testing/GeneratedBlock.tscn"

var mesh_material = preload("res://testing/MeshMaterial.tres")
var outline_material = preload("res://testing/OutlineMaterial.tres")

func _ready():
	pack_mesh(make_mesh("be955c"))

func pack_mesh(target_mesh):
	var packed_scene = PackedScene.new()
	add_child(target_mesh)
	target_mesh.set_owner(self)
	packed_scene.pack(target_mesh)
#	packed_scene.pack(get_tree().get_current_scene())
	ResourceSaver.save(pack_destination, packed_scene)

func make_mesh(xstr) -> Mesh:
	var shape = MeshInstance.new()
	
	var arr_mesh = ArrayMesh.new()
#	var arrays = []
#	arrays.resize(ArrayMesh.ARRAY_MAX)
	
	var cube = CubeMesh.new()
	var outline = cube.create_outline(outline_size)
	
#	add_material_to_surfaces(mesh_material, cube)
#	add_material_to_surfaces(outline_material, outline)
	
	add_surfaces_to_array_mesh(arr_mesh, cube)
	add_surfaces_to_array_mesh(arr_mesh, outline)
	
	var m = MeshInstance.new()
	shape.mesh = arr_mesh
	
	shape.set_surface_material(0, mesh_material)
	shape.set_surface_material(1, outline_material)
	
	return shape
	

func add_material_to_surfaces(material, target_mesh):
	for surface_index in range(target_mesh.get_surface_count()):
		target_mesh.set_surface_material(surface_index, material)
		print("Debug point")

func add_surfaces_to_array_mesh(arr_mesh, from_mesh):
	for surface_index in range(from_mesh.get_surface_count()):
		arr_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, 
			from_mesh.surface_get_arrays(surface_index))
			# add this as the third parameter to the above method if using 
			# blend shapes:
#			from_mesh.surface_get_blend_shape_arrays(surface_index)
