extends KinematicBody


# Declare member variables here. Examples:
var possible_tg = null

var dead = false
var carried = false

var brain

# see player.gd
const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 20
const JUMP_SPEED = 18
const ACCEL = 4 #4.5

var dir = Vector3()

const DEACCEL= 10 #16
const MAX_SLOPE_ANGLE = 40

var STEER_SENSITIVITY = 0.1 #0.05

# Called when the node enters the scene tree for the first time.
func _ready():
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	
	brain = $brain
	
	# get points
	brain.target = get_parent().get_node("nav").get_child(0)
	
	# visualize aabb
#	var debug = $RotationHelper/Character2/Armature/HitBoxTorso/center
#	for i in range(7):
#		var end_point = mesh.get_aabb().get_endpoint(i) # local space
#		 # because we're looking at relative to center
#		var point = to_global(end_point)
#		#var pt = Position3D.new()
#		var msh = CubeMesh.new()
#		msh.size = Vector3(0.25, 0.25, 0.25)
#		var pt = MeshInstance.new()
#		pt.set_mesh(msh)
#		debug.add_child(pt)
#		pt.global_transform.origin =  point



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# see player.gd
func process_movement(delta):
	# Assure our movement direction on the Y axis is zero, and then normalize it.
	dir.y = 0
	dir = dir.normalized()
	# Apply gravity
	vel.y += delta * GRAVITY
	# Set our velocity to a new variable (hvel) and remove the Y velocity.
	var hvel = vel
	hvel.y = 0

	var target = dir
	target *= MAX_SPEED

	# If we have movement input, then accelerate.
	# Otherwise we are not moving and need to start slowing down.
	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL
	#print("Accel, ", accel)
	# Interpolate our velocity (without gravity), and then move using move_and_slide
	hvel = hvel.linear_interpolate(target, accel * delta)
	#print("Interp: ", accel*delta)
	vel.x = hvel.x
	vel.z = hvel.z
	# infinite inertia is now false for better physics when colliding with objects
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE), false)
	
	#print("V: ", vel, " sp: ", vel.length())
	# dunno why the need to invert Z?
	brain.velocity = Vector2(vel.x, -vel.z)
	
	# https://kidscancode.org/godot_recipes/physics/kinematic_to_rigidbody/
	# after calling move_and_slide()
	for index in get_slide_count():
		var collision = get_slide_collision(index)
		if collision.collider.is_in_group("interactable"):
			collision.collider.apply_central_impulse(-collision.normal * 2)

func _physics_process(delta):	
	if dead and not carried:
		# attempt to sync collision with ragdoll
		global_transform.origin = get_node("RotationHelper/Character2/Armature/HitBoxPelvis/Area/CollisionShape").global_transform.origin
		return
		
	# movement
	brain.steer = brain.arrive(brain.target, 5)
	
	# Reset dir, so our previous movement does not effect us
	dir = Vector3()
	
	# Create a vector for storing input
	var input_movement_vector = Vector2()
	# steer y means forward/backwards
	if brain.steer.y > 0:
		input_movement_vector.y += 1
	if brain.steer.y < 0:
		input_movement_vector.y += -1
	#print("input: ", input_movement_vector)
	
	# Normalize the input movement vector so we cannot move too fast
	input_movement_vector = input_movement_vector.normalized()
	
	#print("AI input vec:", input_movement_vector)
	
	# Basis vectors are already normalized.
	dir = get_global_transform().basis.z * input_movement_vector.y
	
	# rotations if any
	self.rotate_y(deg2rad(brain.steer.x * STEER_SENSITIVITY))  #* -1))
	
	process_movement(delta)
		
	
		
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
