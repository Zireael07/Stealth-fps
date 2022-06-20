extends Control


# Declare member variables here. Examples:
var bg_color = Color(0.75,0.75,0.75, 1)
var poi_color = Color(1,0.5,0,1) # orange
var draw_rect
var poi = []

# TODO: make map scale depend on level size
func _3d_tomap2d(vec, lvl_start=Vector2(-50,-50)):
	# map is 1 = 1m scale; so rects are scaled up to be visible (1m = X px)
	var pos = Vector2((vec.x-lvl_start.x)*5, (vec.z-lvl_start.y)*5)
	print("Vec: ", vec, " - 2d map pos: ", pos)
	return pos


# Called when the node enters the scene tree for the first time.
func _ready():
	var map = get_tree().get_nodes_in_group("root")[0].get_node("map")



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _draw():
	for r in draw_rect:
		draw_rect(Rect2(r[0]+1, r[1]+1, r[2]-2, r[3]-2), bg_color)
	for p in poi:	
		draw_circle(p, 5, poi_color)
