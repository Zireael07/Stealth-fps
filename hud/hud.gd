extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$"bottom_panel/Compass".set_text(get_parent().get_compass_heading())
	
	var clr = update_hiding()
	$HidingRect.color = clr
	if get_parent().is_hiding()[1]:
		$HidingLabel.set_text("Shadow")
	else:
		$HidingLabel.set_text("")
	
	
	# update crosshair
	$"Center/Crosshair".set_spread(get_parent())
	
	# update action bar
	if $Center/ActionProgress.visible:
		$Center/ActionProgress/VBoxContainer/ProgressBar.value = get_parent().get_node("ActionTimer").get_time_left()

	# update air bar
	if $AirProgressBar.visible and not get_parent().get_node("AirTimer").is_stopped():
		$AirProgressBar.value = get_parent().get_node("AirTimer").get_time_left()

func update_hiding():
	if get_parent().is_hiding()[0]:
		return Color(0,0,0) # black
	else:
		return Color(1,1,1) # white

func _on_OptionButton_item_selected(index):
	get_parent()._on_gadget_mode(index)


func _on_MessageTimer_timeout():
	# TODO: add a fancy fadeout effect
	get_node("MessagePanel").hide()
