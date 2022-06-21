extends Control


# Declare member variables here. Examples:
var player
# material
var default = preload("res://assets/blue_principled_bsdf.tres")
var camo = preload("res://assets/camo_triplanar_mat.tres")

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player = get_parent().get_parent()
	# make viewport work
	$"ViewportContainer/Viewport/Character/AnimationTree".active = false
	$"ViewportContainer/Viewport/Camera".current = true
	
	# preselect knife
	_on_OptionButtonS_item_selected(0)


func _on_uniform_change(index):
	var msh = $"ViewportContainer/Viewport/Character/Armature/Body"
	if index == 0:
		msh.set_surface_material(1, default)
	elif index == 1:
		msh.set_surface_material(1, camo)

	player.uniform_change(index)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_OptionButtonU_item_selected(index):
	_on_uniform_change(index)


func _on_Button_pressed():
	get_tree().set_pause(false)
	self.queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_Control_gui_input(event):
	# hackfix
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#print(event)


func _on_OptionButtonS_item_selected(index):
	player.starting_inventory(index)
