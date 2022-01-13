extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	$"Panel2/VBoxContainerAnswers/Label".connect("gui_input", self, "_on_answer_gui_input", [$"Panel2/VBoxContainerAnswers/Label"] )
	$"Panel2/VBoxContainerAnswers/Label2".connect("gui_input", self, "_on_answer_gui_input", [$"Panel2/VBoxContainerAnswers/Label2"] )
	
	
	pass # Replace with function body.

func set_answers(list):
	for i in $"Panel2/VBoxContainerAnswers".get_child_count():
		var c = $"Panel2/VBoxContainerAnswers".get_child(i) 
		c.set_text(list[i])


func show_line(text):
	$"Panel2/VBoxContainer/Label".set_text(text)

func show_answers():
	$"Panel2/VBoxContainer".hide()
	$"Panel2/VBoxContainerAnswers".show()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Label_gui_input(event):
	#print(event)
	if event is InputEventMouseButton:
		print("Clicked in convo")
		show_answers()


func _on_answer_gui_input(event, node):
	#print(event)
	if event is InputEventMouseButton:
		print("Clicked on answer ", node)
		
		# end convo
		queue_free()
		
		get_parent().get_parent().talking = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
