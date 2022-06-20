extends Spatial


# Declare member variables here. Examples:
var player

# missions/levels
var outdoor = preload("res://outdoor.tscn")
var indoor_tut = preload("res://indoor_tutorial.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	# if no level chosen pick outdoor for now
	if get_child_count() < 1:
		var lvl = outdoor.instance()
		add_child(lvl)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# TODO: level change effect (e.g. fade to black)
func change_level():
	get_child(0).queue_free()
	var lvl = indoor_tut.instance()
	add_child(lvl)
	# hackfix
	get_tree().get_nodes_in_group("player")[1].set_physics_process(false)
	lvl.setup_map(get_tree().get_nodes_in_group("player")[1])
