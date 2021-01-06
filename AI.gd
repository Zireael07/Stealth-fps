extends KinematicBody


# Declare member variables here. Examples:
var possible_tg = null

var dead = false
var carried = false

# Called when the node enters the scene tree for the first time.
func _ready():
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	# visualize aabb
	var debug = $RotationHelper/Character2/Armature/HitBoxTorso/center
	for i in range(7):
		var end_point = mesh.get_aabb().get_endpoint(i) # local space
		 # because we're looking at relative to center
		var point = to_global(end_point)
		#var pt = Position3D.new()
		var msh = CubeMesh.new()
		msh.size = Vector3(0.25, 0.25, 0.25)
		var pt = MeshInstance.new()
		pt.set_mesh(msh)
		debug.add_child(pt)
		pt.global_transform.origin =  point



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _physics_process(delta):	
	if dead and not carried:
		# attempt to sync collision with ragdoll
		global_transform.origin = get_node("RotationHelper/Character2/Armature/HitBoxPelvis/Area/CollisionShape").global_transform.origin
		return
		
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
	dead = true
	
	# tip him back
	get_node("RotationHelper/Character2").rotate_x(deg2rad(-40))
	# switch off animtree
	get_node("RotationHelper/Character2/AnimationTree").active = false
			
	# ragdoll
	get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()
	
	get_node("RotationHelper/Character2").rotate_x(deg2rad(-50)) # to arrive at -90
	#get_node("CollisionShape").rotate_x(deg2rad(-90))
	get_node("CollisionShape").disabled = true # only the ragdoll should be active
	
	# for AI, rotate the apparent aabb origin by 90 deg to fit the ragdoll
	#get_node("RotationHelper/Character2/Armature/HitBoxTorso/center").rotate_x(deg2rad(-90))
	
	#undo tipback (so that interacting later on works better)
	#get_node("RotationHelper/Character2").rotate_x(deg2rad(40))

func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		possible_tg = body


func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))
