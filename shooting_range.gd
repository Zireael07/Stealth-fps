extends Spatial


# Declare member variables here. Examples:
var player = null

var num_shots = 0
var total = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_nodes_in_group("player")[0]


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func add_shot(score):
	if num_shots <= 10:
		total += score
	
	# update the HUD
	player.get_node("Control/scoring/ScoreLabel").set_text(str(int(total)))
	
	# tell the player he's done
	if num_shots == 10:
		player.get_node("Control/scoring/FinishedScoring").set_text("Finished! Total: " + str(int(total)) + "/100")
	


func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		player.get_node("Control/scoring").show()


func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		player.get_node("Control/scoring").hide()
