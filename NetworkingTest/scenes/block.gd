extends Node3D

@onready var collider = $StaticBody3D/CollisionShape3D
@onready var mesh = $StaticBody3D/MeshInstance3D

"""
Convert transform scale in editor -> collision shape / mesh dimensions. Because
transform-scaled collider is buggy 
"""
func _ready():
	var initial_scale = global_transform.basis.get_scale()
	collider.shape = BoxShape3D.new()
	collider.shape.size = initial_scale
	
	var mesh_shape : BoxMesh = mesh.mesh
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = initial_scale
	
	global_transform.basis = global_transform.basis.orthonormalized()
