extends RigidBody


# Declare member variables here. Examples:
var hits = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_destroy():
	queue_free()
	# TODO: spawn splinters

func _on_hit():
	var destruct = false
	hits = hits + 1
	
	# DX1: darkens the albedo with every hit
	get_node("MeshInstance").get_surface_material(0).albedo_color = get_node("MeshInstance").get_surface_material(0).albedo_color.darkened(0.2)
	
	if hits == 3:
		_on_destroy()
		destruct = true
	
	return destruct
