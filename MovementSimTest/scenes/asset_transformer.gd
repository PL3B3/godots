extends Node3D

const SCALE = 10

func _ready():
	for child in get_children():
		var raw_mesh_instance: MeshInstance3D = child.get_child(0).get_child(0)
		var cleaned_array_mesh: ArrayMesh = raw_mesh_instance.get_mesh().duplicate(true)
		for i in cleaned_array_mesh.get_surface_count():
			var surface_material: StandardMaterial3D = cleaned_array_mesh.surface_get_material(i).duplicate(true)
			surface_material.set_texture_filter(BaseMaterial3D.TEXTURE_FILTER_NEAREST)
			surface_material.set_metallic(0)
			surface_material.set_specular(0.2)
			surface_material.set_roughness(0.8)
			cleaned_array_mesh.surface_set_material(i, surface_material)
		var new_mesh_instance = MeshInstance3D.new()
		new_mesh_instance.set_mesh(cleaned_array_mesh)
		new_mesh_instance.name = child.name
		new_mesh_instance.scale = Vector3(SCALE, SCALE, SCALE)
		new_mesh_instance.create_convex_collision(true, false)
		var c = new_mesh_instance.get_children(true)
		var c1 = new_mesh_instance.get_child(0)
		var c2 = new_mesh_instance.get_child(0).get_child(0)
		new_mesh_instance.get_child(0).set_owner(new_mesh_instance)
		new_mesh_instance.get_child(0).get_child(0).set_owner(new_mesh_instance)
		
		var packed_scene = PackedScene.new()
		packed_scene.pack(new_mesh_instance)
		ResourceSaver.save(packed_scene, "res://addons/cleaned/%s.tscn" % new_mesh_instance.name)
	
	print("FINISHED")
