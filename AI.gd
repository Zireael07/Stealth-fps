extends KinematicBody


# Declare member variables here. Examples:
var possible_tg = null

var dead = false
var carried = false

var brain

var in_sight = false

# see player.gd - this is the anim state machine
var state_machine

const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 2 #10 #20 # in m/s - 4 m/s is a human walking speed
const JUMP_SPEED = 18
const ACCEL = 1 #4 #4.5

var dir = Vector3()

const DEACCEL= 4 #10 #16
const MAX_SLOPE_ANGLE = 40

var STEER_SENSITIVITY = 0.5 #0.05

var target_array = []
var current = 0
var prev = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	state_machine = $RotationHelper/Character2/AnimationTree
	
	brain = $brain
	
	# get points
	for c in get_parent().get_node("nav").get_children():
		target_array.append(c)
	#brain.target = get_parent().get_node("nav").get_child(0)
	brain.target = target_array[0]
	
	
	# fake aabb for outlines
	var debug = $RotationHelper/Character2/Armature/HitBoxTorso/center
	for i in range(7):
		var end_point = mesh.get_aabb().get_endpoint(i) # local space
		 # because we're looking at relative to center
		var point = to_global(end_point)
		var pt = Position3D.new()
		#var msh = CubeMesh.new()
		#msh.size = Vector3(0.25, 0.25, 0.25)
		#var pt = MeshInstance.new()
		#pt.set_mesh(msh)
		debug.add_child(pt)
		pt.global_transform.origin =  point



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func is_close_to_target():
	var ret = false
	var loc = to_local(target_array[current].get_global_transform().origin)
	var dist = Vector2(loc.x, loc.z).length()
	if dist < 1:
		ret = true
	return ret

# see player.gd
func process_movement(delta):
	# Assure our movement direction on the Y axis is zero, and then normalize it.
	dir.y = 0
	# dir is global (see line 145)
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
	#vel.x = 0 # eliminate drift since AI can't strafe
	vel.z = hvel.z
	# infinite inertia is now false for better physics when colliding with objects
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE), false)
	#print("V: ", vel, " sp: ", vel.length())
	
	# x is turning and y is forward/backwards
	brain.velocity = Vector2(0, vel.length())
	
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
	
	if not dead:
		# animate movement
		if vel.length() > 0:
			state_machine["parameters/move_state/run/blend_position"] = Vector2(0,1) # actually animates leg movement
		else:
			state_machine["parameters/move_state/run/blend_position"] = Vector2(0,0) # stop moving
		
		if not in_sight:
			# movement
			brain.steer = brain.arrive(brain.target, 15)
			
			# rotations if any
			self.rotate_y(deg2rad(brain.steer.x * STEER_SENSITIVITY))  #* -1))
			
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
			
			process_movement(delta)
			
			if is_close_to_target():
				##do we have a next point?
				if (target_array.size() > current+1):
					prev = current
					current = current + 1
				else:
					# assume all AI paths are loops for now
					current = 0

				# send to brain
				brain.target = target_array[current]
		
	if not possible_tg:
		in_sight = false
		return
		
	if dead:
		in_sight = false
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
			
			# look at player
			look_at(body_r.global_transform.origin, Vector3(0,1,0))
			# because this looks the opposite way for some reason
			rotate_y(deg2rad(180))
			in_sight = true
			
		# can't see the player
		else:
			get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,0))
			in_sight = false

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
