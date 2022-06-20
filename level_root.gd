extends Spatial


# Declare member variables here. Examples:
#var player

func setup_map(player=null):
	# pass things around (map is initialized too late to access it from player setup)
	if player == null:
		player = get_tree().get_nodes_in_group("player")[0]
	var map = get_node("map")
	# this is for indoor tutorial
	var map_rect = [[0,22,50,4]]
	# if we have a map node, we're not the tutorial
	if has_node("map"):
		map_rect = map.contain
	var map_screen = player.get_node("Control/map_screen/map")

	# TODO: make map scale depend on level size
	# scale things up for drawing (map scale is 1 = 1m)
	# 1 m = X px on map
	var draw_rect = []	
	for m in map_rect:
		var d = [m[0]*5, m[1]*5, m[2]*5, m[3]*5]
		draw_rect.append(d)

	
	map_screen.draw_rect = draw_rect
	
	
	var poi = map_screen.poi

	if map != null:
		poi.append(map_screen._3d_tomap2d(map.get_child(0).get_translation())) #target range
		poi.append(map_screen._3d_tomap2d(map.get_child(1).get_translation())) # crates
		poi.append(map_screen._3d_tomap2d(map.get_child(3).get_translation())) # helicopter
	else:
		poi.append(map_screen._3d_tomap2d(get_node("supply box").get_translation(), Vector2(-25, -25)))

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_map()	


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
