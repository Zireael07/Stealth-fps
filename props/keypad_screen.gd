# workaround for Godot "viewport texture" resource issue
tool
extends MeshInstance

var camera = null


func _ready():
	#$"../Viewport".set_size(Vector2(1024/2, 600/2))
	
	
	#var t = get_tree().get_nodes_in_group("cctv")[0].get_node("Viewport").get_texture()
	var t = get_node("../Viewport").get_texture()
	
	#get_material_override().albedo_texture = t
	get_material_override().set_shader_param("refl_tx", t)
