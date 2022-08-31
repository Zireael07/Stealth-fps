extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	$VBoxContainer/LineEdit.clear()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func add_notes(txt):
	var note = $VBoxContainer/LineEdit.duplicate()
	note.editable = false
	note.text = txt
	$VBoxContainer.add_child(note)


func _on_LineEdit_gui_input(event):
	get_parent().get_parent().talking = true # prevent player reacting to letters entered


func _on_LineEdit_text_entered(new_text):
	add_notes(new_text)
	$VBoxContainer/LineEdit.clear()
