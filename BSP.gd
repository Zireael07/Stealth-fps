extends Node


# BSP
# based on https://www.youtube.com/watch?v=hFgDjvLXq2g
var rect1
var rect2
var contain
var bak = []
var start_rect

var avail

# Called when the node enters the scene tree for the first time.
func _ready():
	# x,y,w,h
	start_rect = [0,0, 35, 35]
	contain = [start_rect]
	
	rect(contain)
	rect(contain)
	
	print(contain)
	
	for c in contain:
		print(c, center(c))
	
	# random selection
	avail = contain.duplicate()
	randomize()
	var i = randi() % 3 # between 0 and 3
	var sel = avail[i]

	# target range
	get_child(0).set_translation(Vector3(center(sel).x, 0, center(sel).y))
	
	avail.remove(i)
	
	i = randi() % 2
	sel = avail[i]
	# crates
	get_child(1).set_translation(Vector3(center(sel).x, 0, center(sel).y))
	# move the crate nav to match
	get_node("/root/Spatial/nav2").set_translation(Vector3(center(sel).x, 0, center(sel).y))


# --------------------------
# 2d bsp
func center(contain):
	var x = ceil(contain[2] / 2)
	var y = ceil(contain[3] / 2)
	return Vector2(contain[0] + x, contain[1]+y)

func rect(contain):
	bak.clear()
	for rect in contain:
		randomize()
		if rect[2] > rect[3]:
			# 30-70% of width
			var w = round(rand_range(.3, .7)*rect[2])
			rect1 = [rect[0], rect[1], w, rect[3]]
			rect2 = [rect[0]+w, rect[1], rect[2]-w, rect[3]]
		else:
			var h = round(rand_range(.3, .7)*rect[3])
			rect1 = [rect[0], rect[1], rect[2], h]
			rect2 = [rect[0], rect[1]+h, rect[2], rect[3]-h]

		bak.append(rect1)
		bak.append(rect2)

	contain.clear()
	for r in bak:
		contain.append(r)
