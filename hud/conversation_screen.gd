extends Control


# Declare member variables here. Examples:
var talker = null
var dialog = null
var current_tag = null

# Called when the node enters the scene tree for the first time.
func _ready():
	$"Panel2/VBoxContainerAnswers/Label1".connect("gui_input", self, "_on_answer_gui_input", [$"Panel2/VBoxContainerAnswers/Label1"] )
	$"Panel2/VBoxContainerAnswers/Label2".connect("gui_input", self, "_on_answer_gui_input", [$"Panel2/VBoxContainerAnswers/Label2"] )

# for things that need the npc (e.g. changing AI's behavior)	
func set_talker(npc):
	talker = npc


func clear_answers():
	for i in $"Panel2/VBoxContainerAnswers".get_child_count():
		var c = $"Panel2/VBoxContainerAnswers".get_child(i)
		c.set_text("")
		
func set_answers(list):
	for i in $"Panel2/VBoxContainerAnswers".get_child_count():
		var c = $"Panel2/VBoxContainerAnswers".get_child(i)
		if i < list.size():
			c.set_text(list[i])


func show_line(text, tag):
	$"Panel2/VBoxContainer".show()
	$"Panel2/VBoxContainerAnswers".hide()
	$"Panel2/VBoxContainer/Label".set_text(text)
	current_tag = tag

func show_answers():
	$"Panel2/VBoxContainer".hide()
	$"Panel2/VBoxContainerAnswers".show()

func load_dialogue(dialogue):
	# paranoia
	if not dialogue is DialogueResource:
		return
	
	dialog = dialogue
	set_answers(dialogue.answers["start"])
	show_line(dialogue.lines["start"], "start")


func _on_answer_selected(gui, id):
	#if '_on_answer_selected' in talker:
	var ret = talker._on_answer_selected(self, id)
	# is it the end?
	if ret != null:
		return ret
	else:
		return true

func _on_Label_gui_input(event):
	#print(event)
	if event is InputEventMouseButton:
		print("Clicked in convo")
		show_answers()


func _on_answer_gui_input(event, node):
	#print(event)
	if event is InputEventMouseButton:
		print("Clicked on answer ", node)
		
		var number = node.get_name().split("Label")[1]
		#print(number)
		var end = _on_answer_selected(self, int(number))
		#print("end:", end)
		if end:
			# end convo
			queue_free()
			
			get_parent().get_parent().talking = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
			get_parent().get_parent()._on_convo_end(self.talker)
		
		return
