extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	$VBoxContainer/LineEdit.clear()
	# only the original needs the connection
	$VBoxContainer/LineEdit.connect("text_entered", self, "_on_LineEdit_text_entered")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func add_notes(txt, edit=false):
	var note = $VBoxContainer/LineEdit.duplicate()
	note.editable = edit
	note.text = txt
	$VBoxContainer.add_child_below_node($VBoxContainer/HSeparator, note)
	#$VBoxContainer.move_child(note, 2)


func _on_LineEdit_gui_input(event):
	get_parent().get_parent().talking = true # prevent player reacting to letters entered

# called upon pressing Enter on line edit
func _on_LineEdit_text_entered(new_text):
	add_notes(new_text, true)
	$VBoxContainer/LineEdit.clear()
