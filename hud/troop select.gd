extends Control


# Declare member variables here. Examples:
var player


# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_parent().get_parent()
	
	# unfortunately this kind of additional parameter can't be done through editor UI
	get_node("HBoxContainer/VBoxContainer/Button").connect("pressed", self, "_on_Button_pressed", [get_node("HBoxContainer/VBoxContainer/Button")])
	get_node("HBoxContainer/VBoxContainer2/Button").connect("pressed", self, "_on_Button_pressed", [get_node("HBoxContainer/VBoxContainer2/Button")])


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_Button_pressed(src):
	var nm = src.get_parent().get_node("HBoxContainer/Label").get_text()
	print("Selected ", nm)
	
	var data = [nm]
	
	# hide
	queue_free()
	# unpause
	get_tree().set_pause(false)
	
	player.get_node("Control/outfit_select").show()
	get_tree().set_pause(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	player.game_start(data)
