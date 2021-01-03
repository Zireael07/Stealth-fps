extends KinematicBody


# Declare member variables here. Examples:
var possible_tg = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _physics_process(delta):
	if not possible_tg:
		return
	
	# Can we see the player?
	# Get the raycast node
	var ray = $RotationHelper/Area/RayCast
	
	# set the proper cast_to
	ray.cast_to = ray.to_local(possible_tg.get_global_transform().origin)
	
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body_r = ray.get_collider()
		#print("Body_r", body_r)
		if body_r is KinematicBody:
			get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,0,0))
		# can't see the player
		else:
			get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,0))

func die():
	# tip him back
	get_node("RotationHelper/Character2").rotate_x(deg2rad(-40))
	# switch off animtree
	get_node("RotationHelper/Character2/AnimationTree").active = false
			
	# ragdoll
	get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()


func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		possible_tg = body


func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))
