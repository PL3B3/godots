extends MarginContainer

onready var map_container = get_node("MapContainer")
onready var map_tex_node = get_node("MapContainer/TextureRect")
onready var server = get_node("/root/ChubbyServer")
onready var player_marker = get_node("MapContainer/TextureRect/PlayerMarker")

var map_scale = 0.15
var player_spawned = false
var player
var map_origin_absolute
var map_container_scale = Vector2(1,1)

func _ready():
	server.connect("minimap_texture_updated", self, "_on_minimap_texture_updated")
	server.connect("player_spawned", self, "_on_player_spawned")
	self.connect("mouse_entered", self, "_on_mouse_entered")
	map_tex_node.connect("resized", self, "_on_resized")

func _process(delta):
	if player_spawned:
		if player == null:
			player = server.get_node(str(server.client_id))
		else:
			var scaled_position = (player.get_global_position() - map_origin_absolute) * map_scale
			scaled_position.x *= map_container_scale.x
			scaled_position.y *= map_container_scale.y
			player_marker.position = scaled_position

func _unhandled_key_input(event):
	if event is InputEventKey:
		if event.pressed && !event.echo && event.scancode == KEY_M:
			# Toggle visibility
			set_visible(!is_visible())

func _on_resized():
	map_container_scale.x = map_tex_node.get_size().x / get_size().x
	map_container_scale.y = map_tex_node.get_size().y / get_size().y
	print(map_container_scale)

func _on_player_spawned():
	player_spawned = true


func _on_mouse_entered():
	#print("mouse has come")
	#set_visible(true)
	pass

func _on_minimap_texture_updated(tex: Texture, origin: Vector2):
	map_tex_node.set_texture(tex)
	map_origin_absolute = origin
	margin_left = map_scale * -0.5 * tex.get_width()
	margin_right = map_scale * 0.5 * tex.get_width()
	margin_top = map_scale * -0.5 * tex.get_height()
	margin_bottom = map_scale * 0.5 * tex.get_height()
	#rect_size = 0.1 * tex.get_size()
