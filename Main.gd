extends Spatial


# Declare member variables here. Examples:
var player
var indoor_tut = preload("res://indoor_tutorial.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	# pass things around (map is initialized too late to access it from player setup)
	player = get_tree().get_nodes_in_group("player")[0]
	var map = get_tree().get_nodes_in_group("root")[0].get_node("map")
	# FIXME: generate map for indoor level too
	var map_rect = map.contain
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

	poi.append(map_screen._3d_tomap2d(map.get_child(0).get_translation())) #target range
	poi.append(map_screen._3d_tomap2d(map.get_child(1).get_translation())) # crates
	poi.append(map_screen._3d_tomap2d(map.get_child(2).get_translation())) # helicopter

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# TODO: level change effect (e.g. fade to black)
func change_level():
	self.queue_free()
	var lvl = indoor_tut.instance()
	get_node("/root").add_child(lvl)
	# hackfix
	get_tree().get_nodes_in_group("player")[1].set_physics_process(false)
