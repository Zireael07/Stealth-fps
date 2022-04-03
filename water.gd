tool
extends Spatial


# Declare member variables here. Examples:
export var size = Vector3(10,2.5, 10)


# Called when the node enters the scene tree for the first time.
func _ready():
	# auto size things
	get_node("WaterArea/CollisionShape").get_shape().set_extents(size/2) #extents are half the actual size
	get_node("surface").get_mesh().set_size(Vector2(size.x, size.z))
	get_node("MeshInstance2").set_scale(size/2)
	# fix y offset
	var offset = (-size.y/2)-0.05
	get_node("WaterArea/CollisionShape").set_translation(Vector3(0, offset, 0))
	get_node("MeshInstance2").set_translation(Vector3(0,offset, 0))
	
	
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
