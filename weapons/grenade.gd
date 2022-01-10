extends RigidBody


# Declare member variables here. Examples:
var armed
var possible_tg = []
var player = null

var attached = false
var attach_point = null

var slot # for inventory
var droppable = true

# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_nodes_in_group("player")[0]

func explode():
	print("Explode!")
	# deal damage
	for b in possible_tg:
		if b.is_in_group("AI"):
			b.die(get_global_transform().origin)

	queue_free()

func flash():
	print("Timer over!!!")

	for b in possible_tg:
		if b.is_in_group("AI"):
			b.drop_gun(player)
		if b.is_in_group("player"):
			# flash the player
			player.get_node("Control/flashbang").show()
			player.get_node("Control/AnimationPlayer").play("flash")

	queue_free()

func gas():
	get_node("Particles").emitting = true
	
	for b in possible_tg:
		if b.is_in_group("AI"):
			b.drop_gun(player)
		if b.is_in_group("player"):
			# UI effects for the player
			player.get_node("Control/flashbang").show()
			player.get_node("Control/gas_overlay").show()
			player.get_node("Control/AnimationPlayer").play("gas")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# If we have attached to something, then stick to the point we attached to
	if attached == true:
		if attach_point != null:
			global_transform.origin = attach_point.global_transform.origin
#	pass


#func _on_Timer_timeout():
	#print("Timer over!!!!")
#	explode()
	#pass # Replace with function body.


func _on_Area_body_entered(body):
	if body is KinematicBody and self.armed:
		possible_tg.append(body)
		print("Possible grenade tg: ", body)


func _on_Area_body_exited(body):
	if body is KinematicBody:
		possible_tg.remove(possible_tg.find(body))


func _on_StickyArea_body_entered(body):
	stick_to_body(body)

# based on Godot FPS tutorial	
func stick_to_body(body):
	# only stick to Static or Rigidbodies
	if body is KinematicBody:
		return
	
	# Make sure we are not colliding with ourself
	if body == self:
		return
	
	# We do not want to collide with the player that's thrown this grenade
	if body == player:
		return
		
	# Don't want to stick to floor or other grenades
	if body.is_in_group("floor") or body.is_in_group("grenade"):
		return
	
	if attached == false:
		# Attach ourselves to the body at that position.
		# We will do this by making a new Spatial node, and making it a child of the body we
		# collided with. Then we will set it's transform to our transform, and the follow
		# that node in _process
		attached = true
		attach_point = Spatial.new()
		body.add_child(attach_point)
		attach_point.global_transform.origin = global_transform.origin
		
		# Disable our collision shape so we don't knock the body we've attached to around while we're stuck to it
		$CollisionShape.disabled = true
		
		# Set our mode to MODE_STATIC so the grenade does not move around
		mode = RigidBody.MODE_STATIC
		
		# Longer timer
		get_node("Timer").start(5.0)

func armed_flash():
	$AnimationPlayer.play("armed_flash")
