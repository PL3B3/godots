extends Node3D

const SCALE = 30
const BASE_ASSET_PATH = "res://assets/buildings/"
const SCENE_PATH = "res://assets/buildings/%s/%s.tscn"

func _ready():
	var dir = DirAccess.open("res://assets")
	dir.remove("buildings")
	dir.make_dir("buildings")
	for child in get_children():
		var folder_name = child.name
		for original_mesh_node in child.get_children():
			var raw_mesh_instance: MeshInstance3D = original_mesh_node.get_child(0).get_child(0)
			var cleaned_array_mesh: ArrayMesh = transform_mesh(raw_mesh_instance)
			var new_mesh_instance = MeshInstance3D.new()
			new_mesh_instance.set_mesh(cleaned_array_mesh)
			new_mesh_instance.name = original_mesh_node.name
			new_mesh_instance.scale = Vector3(SCALE, SCALE, SCALE)
			new_mesh_instance.create_convex_collision(true, false)
			var c = new_mesh_instance.get_children(true)
			var c1 = new_mesh_instance.get_child(0)
			var c2 = new_mesh_instance.get_child(0).get_child(0)
			new_mesh_instance.get_child(0).set_owner(new_mesh_instance)
			new_mesh_instance.get_child(0).get_child(0).set_owner(new_mesh_instance)
			save_scene(new_mesh_instance, folder_name)
	get_tree().quit()

func transform_mesh(original_mesh: MeshInstance3D) -> ArrayMesh:
	var cleaned_array_mesh: ArrayMesh = original_mesh.get_mesh().duplicate(true)
	for i in cleaned_array_mesh.get_surface_count():
		var surface_material: StandardMaterial3D = cleaned_array_mesh.surface_get_material(i).duplicate(true)
		surface_material.set_texture_filter(BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		surface_material.set_metallic(0)
		surface_material.set_specular(0.2)
		surface_material.set_roughness(0.8)
		cleaned_array_mesh.surface_set_material(i, surface_material)
	return cleaned_array_mesh

func save_scene(scene_instance: Node, folder_name: String):
	var dir = DirAccess.open(BASE_ASSET_PATH)
	dir.make_dir(folder_name)
	var packed_scene = PackedScene.new()
	packed_scene.pack(scene_instance)
	ResourceSaver.save(packed_scene, SCENE_PATH % [folder_name, scene_instance.name])
