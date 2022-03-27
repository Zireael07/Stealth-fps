extends Area


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		yield(get_tree().create_timer(0.5), "timeout")
		body.get_node("Control/MessagePanel").show()
		yield(get_tree().create_timer(5), "timeout")
		# TODO: add a fancy fadeout effect
		body.get_node("Control/MessagePanel").hide()
