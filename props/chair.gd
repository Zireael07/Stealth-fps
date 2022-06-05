extends RigidBody


# Declare member variables here. Examples:
export var sitting = true setget set_sitting
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	#set_sitting(true)
	pass

func set_sitting(boo):
	print("Setter!")
	#if !is_inside_tree():
	#	return
		
	if boo:
		#sitting = true
		remove_from_group("interactable")
		$CollisionShape.disabled = true
		if is_inside_tree():
			print("Set sitting to true: ", get_parent().get_name())
	else:
		add_to_group("interactable")
		$CollisionShape.disabled = false
		if is_inside_tree():
			print("Set sitting to false: ", get_parent().get_name())
	
func set_interact():
	sitting = false
	add_to_group("interactable")
	$CollisionShape.disabled = false

func _on_interact():
	set_sitting(true)
	var player = get_tree().get_nodes_in_group("player")[0]
	player.global_transform = self.global_transform
	
	# crouching character is roughly 0.4 (1.7 to 1.3) lower
	player.get_node("CollisionShape").set_translation(Vector3(0,0.527,0.324))
	player.get_node("see_tg").set_translation(Vector3(0, 0.527, 0.324))
	player.get_node("CollisionShape").get_shape().extents = Vector3(0.249, 0.52, 0.757)
	
	# dummy to prevent player doing things while sitting
	player.talking = true
	
	# trigger convo if there is another chair
	var chairs = get_tree().get_nodes_in_group("chair")
	for c in chairs:
		if c != self:
			print("Detected another chair")
			# FIXME: hardcoded for now
			var b = get_tree().get_nodes_in_group("boss")[0]
			player.talk_to_NPC(b)

