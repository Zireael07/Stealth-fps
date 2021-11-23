extends Spatial


# Declare member variables here. Examples:
var alarmed = false

var red = preload("res://assets/red.material")
var grey = preload("res://assets/Grey.material")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_interact():
	alarmed = not alarmed
	
	if alarmed:
		get_child(1).set_surface_material(1, red)
	else:
		get_child(1).set_surface_material(1, grey)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
