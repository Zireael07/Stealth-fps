extends Spatial


# Declare member variables here. Examples:
var player


# Called when the node enters the scene tree for the first time.
func _ready():
	# pass things around
	player = get_tree().get_nodes_in_group("player")[0]
	var map = get_tree().get_nodes_in_group("root")[0].get_node("map")
	var map_rect = get_tree().get_nodes_in_group("root")[0].get_node("map").contain

	# scale things up for drawing (map scale is 1 = 1m(
	var draw_rect = []	
	for m in map_rect:
		var d = [m[0]*10, m[1]*10, m[2]*10, m[3]*10]
		draw_rect.append(d)

	
	player.get_node("Control/map_screen/map").draw_rect = draw_rect



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
