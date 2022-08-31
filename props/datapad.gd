extends Spatial


# Declare member variables here. Examples:
var alarmed = false

var cyan = preload("res://assets/cyan.tres")
var grey = preload("res://assets/Grey.material")
var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_nodes_in_group("player")[0]

func _on_interact():
	# TODO: pickup animation; change color of the "screen"
	player.get_node("Control/info").show()
	var txt = "TODO: send the newest Agent on the training mission"
	player.get_node("Control/info/RichTextLabel").set_text(txt)
	player.add_note(txt)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
