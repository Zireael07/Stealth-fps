extends RigidBody


# Declare member variables here. Examples:
var possible_tg = []


# Called when the node enters the scene tree for the first time.
func _ready():
	#translate(Vector3(0,1, 0))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func explode():
	for b in possible_tg:
		# exclude Areas used by AI
		if b is Area and !b.get_parent().get_parent().is_in_group("AI"):
			print("Possible tg: ", b.get_parent().get_name())
			b.get_parent().queue_free()
		elif b is KinematicBody:
			b.die()
	
	queue_free()


func _on_Area_body_entered(body):
	if body is KinematicBody:
		print("Body in blast range: ", body.get_name())
		possible_tg.append(body)


func _on_Area_body_exited(body):
	if body is KinematicBody:
		print("Body not in blast range: ", body.get_name())
		possible_tg.remove(possible_tg.find(body))

# blast destroys lasers
func _on_Area_area_entered(area):
	print("Area in blast range")
	possible_tg.append(area)
	pass # Replace with function body.


func _on_Area_area_exited(area):
	print("Area not in blast range")
	possible_tg.remove(possible_tg.find(area))
	pass # Replace with function body.
