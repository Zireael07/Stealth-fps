extends Spatial


# Declare member variables here. Examples:
var alarmed = false

var red = preload("res://assets/red.material")
var grey = preload("res://assets/Grey.material")
var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_nodes_in_group("player")[0]

func _on_interact():
	alarmed = not alarmed
	
	if alarmed:
		get_child(1).set_surface_material(1, red)
		# player HUD
		player.get_node("Control/AlertLabel").show()
	else:
		get_child(1).set_surface_material(1, grey)
		# player HUD
		player.get_node("Control/AlertLabel").hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
