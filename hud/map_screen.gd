extends Control


# Declare member variables here. Examples:
var color = Color(1,1,1,1)
var draw_rect


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _draw():
	for r in draw_rect:
		draw_rect(Rect2(r[0]+1, r[1]+1, r[2]-2, r[3]-2), color)
