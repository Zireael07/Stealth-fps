extends RigidBody


# Declare member variables here. Examples:
export var sitting = true setget set_sitting
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	#set_sitting(true)
	pass

func set_sitting(boo):
	print("Setter!")
	#if !is_inside_tree():
	#	return
		
	if boo:
		#sitting = true
		remove_from_group("interactable")
		$CollisionShape.disabled = true
		if is_inside_tree():
			print("Set sitting to true: ", get_parent().get_name())
	else:
		add_to_group("interactable")
		$CollisionShape.disabled = false
		if is_inside_tree():
			print("Set sitting to false: ", get_parent().get_name())
	
func set_interact():
	sitting = false
	add_to_group("interactable")
	$CollisionShape.disabled = false

#func _on_interact():
#	pass

