extends StaticBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_interact():
	var player = get_tree().get_nodes_in_group("player")[0]
	player.talk_to_NPC(self)

func _on_answer_selected(screen, id):
	if id == 1:
		get_node("/root/Spatial").change_level()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
