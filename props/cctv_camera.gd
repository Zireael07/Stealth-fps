tool
extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	get_node("Viewport/Camera").set_translation(get_node("MeshInstance").get_global_transform().origin+Vector3(0,0,0.75/2))
	
	get_node("Viewport/Camera").rotate_x(get_node("MeshInstance").get_rotation().x)
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Button_pressed():
	print("Should disable camera!")
	get_node("Viewport/Camera").current = false
	
	pass # Replace with function body.
