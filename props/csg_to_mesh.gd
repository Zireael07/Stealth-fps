extends CSGShape


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	_update_shape()
	var msh = get_meshes()
	ResourceSaver.save("res://button_mesh.tres",msh[1])


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
