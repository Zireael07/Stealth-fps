extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	# TODO: auto size things
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_WaterArea_body_entered(body):
	if body.is_in_group("player"):
		body.swimming = true
		body.water_body = self
		body.get_node("Control/AirProgressBar").show()
	#pass # Replace with function body.


func _on_WaterArea_body_exited(body):
	if body.is_in_group("player"):
		body.swimming = false
		body.water_body = null
		body.get_node("Control/AirProgressBar").hide()
