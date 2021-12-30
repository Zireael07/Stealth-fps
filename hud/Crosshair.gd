extends Control


# Declare member variables here. Examples:
# initial values
var size = Vector2(42,42)
var bottom = Vector2(18.5, 25.5)
var top = Vector2(18.5, 0.5)
var left = Vector2(16.5, 18.5)
var right = Vector2(40.5, 18.5)


# Called when the node enters the scene tree for the first time.
func _ready():
	size = size/2
	pass # Replace with function body.

func set_spread(player):
	if !player.is_gun():
		return
	
	var spread = player.cur_spread
	if spread != 0:
		$Bottom_IMG.rect_position = Vector2(bottom.x, bottom.y+(spread*size.y))
		$Top_IMG.rect_position = Vector2(top.x, top.y-(spread*size.y))
		$Left_IMG.rect_position = Vector2(left.x-(spread*size.x), left.y)
		$Right_IMG.rect_position = Vector2(right.x+(spread*size.y), right.y)
	else:
		$Bottom_IMG.rect_position = bottom
		$Top_IMG.rect_position = top
		$Left_IMG.rect_position = left
		$Right_IMG.rect_position = right
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
