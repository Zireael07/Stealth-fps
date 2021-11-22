extends RigidBody


# Declare member variables here. Examples:
var armed
var possible_tg
var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_nodes_in_group("player")[0]

func explode():
	print("Explode!")
	# deal damage
	if possible_tg:
		possible_tg.die()

	queue_free()

func flash():
	print("Timer over!!!")

	# flash the player
	player.get_node("Control/flashbang").show()
	player.get_node("Control/AnimationPlayer").play("flash")

	if possible_tg:
		possible_tg.drop_gun()

	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


#func _on_Timer_timeout():
	#print("Timer over!!!!")
#	explode()
	#pass # Replace with function body.


func _on_Area_body_entered(body):
	if body is KinematicBody:
		possible_tg = body
		print("Possible grenade tg: ", body)


func _on_Area_body_exited(body):
	possible_tg = null
