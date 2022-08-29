extends StaticBody


# Declare member variables here. Examples:
var player = null


# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_nodes_in_group("player")[0]

func _on_interact():
	# test: disable atm collision
	#$CollisionShape.disabled = true
	# move player closer to the screen
	player.global_translation = global_transform.origin+Vector3(0,1,-1.6)
	#player.set_translation(Vector3(11.95, -7.4, 23.3))
	player.set_rotation(Vector3(0,0,0)) # prevent the player looking somewhere to the side when starting 
	# flag
	player.using_terminal = true
	
	# give input the focus
	$screen/Viewport/SpinBox.grab_click_focus()
	$screen/Viewport/SpinBox.grab_focus()
	$screen/Viewport/SpinBox.get_child(0).context_menu_enabled = false
	# clear to prevent any previous values showing up
	$screen/Viewport/SpinBox.get_child(0).clear()

	$screen._on_interact()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Button_pressed():
	var val = $screen/Viewport/SpinBox.value
	print("Want to withdraw ", val)
	
