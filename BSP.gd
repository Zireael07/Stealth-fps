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
	bsp()
	place()
	
func bsp():
	# x,y,w,h
	start_rect = [0,0, 85, 85]
	contain = [start_rect]
	
	rect(contain)
	rect(contain)
	
	print(contain)
	
	for c in contain:
		print(c, center(c))
	
# lvl_start is the leftmost end of level extents
# remember that coordinates will increase, so should be min(x) and min(y)
func place(lvl_start=Vector2(-50,-50)):
	# random selection
	avail = contain.duplicate()
	randomize()
	var i = randi() % 3 # between 0 and 3
	var sel = avail[i]
	var pos = _2d_to_level(lvl_start, center(sel))
	
	# target range
	get_child(0).set_translation(Vector3(pos.x, 0, pos.y))
	print("Placed target range at ", Vector3(pos.x, 0, pos.y))
	
	avail.remove(i)
	
	i = randi() % 2
	sel = avail[i]
	pos = _2d_to_level(lvl_start, center(sel))
	
	# crates
	get_child(1).set_translation(Vector3(pos.x, 0, pos.y))
	# move the crate nav to match
	var root = get_tree().get_nodes_in_group("root")[0]
	root.get_node("nav2").set_translation(Vector3(pos.x, 0, pos.y))
	print("Placed crates at ", Vector3(pos.x, 0, pos.y))
	
	# TODO: ensure at least 30 m of separation between POIs?

func _2d_to_level(lvl_start, pos_2d):
	# see line 21
	return Vector2(lvl_start.x+pos_2d.x, lvl_start.y+pos_2d.y)


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
