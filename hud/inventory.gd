extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func update_slot(item):
	if item.slot == "GRENADE":
		$"VBoxContainer/HBoxGrenade1/OptionButton".add_item(item.get_name(), 0)
		$"VBoxContainer/HBoxGrenade1/OptionButton".select(0)
	if item.slot == "GRENADE2":
		$"VBoxContainer/HBoxGrenade2/OptionButton2".add_item(item.get_name(), 0)
		$"VBoxContainer/HBoxGrenade1/OptionButton".select(0)
