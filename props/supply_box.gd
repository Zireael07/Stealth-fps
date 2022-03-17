extends RigidBody


# Declare member variables here. Examples:
var hits = 0

var splinters = load("res://props/splinters.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_destroy():
	queue_free()
	# spawn splinters
	var s = splinters.instance()
	get_parent().add_child(s)
	s.global_transform.origin = self.global_transform.origin
	s.translate_object_local(Vector3(1,-0.5, 0)) # the box was 1m tall and 1 m deep, so we put the splinters on the floor

func _on_hit():
	var destruct = false
	hits = hits + 1
	
	# DX1: darkens the albedo with every hit
	get_node("MeshInstance").get_surface_material(0).albedo_color = get_node("MeshInstance").get_surface_material(0).albedo_color.darkened(0.2)
	
	if hits == 3:
		_on_destroy()
		destruct = true
	
	return destruct
