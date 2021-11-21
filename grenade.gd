extends RigidBody


# Declare member variables here. Examples:
var armed
var possible_tg


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func explode():
	# deal damage
	if possible_tg:
		possible_tg.die()

	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Timer_timeout():
	print("Timer over!!!!")
	explode()
	#pass # Replace with function body.


func _on_Area_body_entered(body):
	if body is KinematicBody:
		possible_tg = body
		print("Possible grenade tg: ", body)


func _on_Area_body_exited(body):
	possible_tg = null
