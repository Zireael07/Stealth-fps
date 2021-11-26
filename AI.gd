extends KinematicBody


# Declare member variables here. Examples:
export var nav: NodePath = "/root/Spatial/nav"
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

var alarmed = false

var face_pos = Vector3()

# Called when the node enters the scene tree for the first time.
func _ready():
	# b/c it's placed in global space
	get_node("MeshInstance").set_as_toplevel(true)
	#get_node("RotationHelper/Character2/Timer").connect("timeout", self, "ragdoll")
	
	
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	state_machine = $RotationHelper/Character2/AnimationTree
	
	brain = $brain
	
	# get points
	for c in get_node(nav).get_children():
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
	var loc = to_local(brain.target.get_global_transform().origin)
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
	
	# debug
	get_node("MeshInstance").set_translation(global_transform.origin+Vector3(vel.x, 0, vel.z))
	# transform global velocity to local
	var loc_vel = to_local(global_transform.origin+vel)
	
	# x is turning and y is forward/backwards
	brain.velocity = Vector2(0, loc_vel.z) #vel.length())
	
	# https://kidscancode.org/godot_recipes/physics/kinematic_to_rigidbody/
	# after calling move_and_slide()
	for index in get_slide_count():
		var collision = get_slide_collision(index)
		if collision.collider.is_in_group("interactable"):
			collision.collider.apply_central_impulse(-collision.normal * 2)

func move(delta):
	brain.steer = brain.arrive(brain.target, 5)
	
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
		
		# do we want to rotate? do it!
		if face_pos and not in_sight:
			#print("Turning to face: ", face_pos)
			
			var rel_loc = to_local(face_pos)
			# we use this simple solution cribbed from my other projects
			# since lerp() or angle_to() between two angles like to produce rotations the long way around....
			
			#2D angle to target (local coords)
			var angle = atan2(rel_loc.x, rel_loc.z)
			#print("Local position of hit: ", rel_loc, "angle: ", angle)
			
			if abs(angle) > deg2rad(5): 
				var ro = angle*STEER_SENSITIVITY*STEER_SENSITIVITY
				#print("Rotating by: ", ro)
				self.rotate_y(ro)
			else:
				# reached our target facing... look this way for some time only
				if get_node("Timer").is_stopped():
					get_node("Timer").start()
			#	face_pos = Vector3()
			
			
			
			#brain.steer = brain.arrive(face_pos, 5)
			# rotation
			#self.rotate_y(deg2rad(brain.steer.x * STEER_SENSITIVITY))  #* -1))
			
			# note to self: looking_at, interpolate_with or lerp don't work since we're a KinematicBody
			
			#var tg = self.transform.looking_at(face_pos, Vector3(0,1,0))
			#transform = transform.interpolate_with(tg, 0.002*delta) #.rotated(Vector3(0,1,0), deg2rad(180))
			# see line 255, because this looks the opposite way for some reason
			#rotate_y(deg2rad(180))
		
		if not in_sight and not face_pos:
			# movement
			move(delta)
			
			if is_close_to_target() and not alarmed:
				##do we have a next point?
				if (target_array.size() > current+1):
					prev = current
					current = current + 1
				else:
					# assume all AI paths are loops for now
					current = 0

				# send to brain
				brain.target = target_array[current]
		
		if alarmed:
			brain.target = get_tree().get_nodes_in_group("alarm")[0]
			
			move(delta)
			
			if alarmed and is_close_to_target():
				print("Reached button")
				#interact with it
				get_tree().get_nodes_in_group("alarm")[0].get_child(0)._on_interact()
				alarmed = false
		
	if not possible_tg:
		in_sight = false
		alarmed = false
		return
		
	if dead:
		in_sight = false
		alarmed = false
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
			# if we see an enemy, no longer need to turn to face a shot
			face_pos = Vector3()
			
			# if we see the player for the first time:
			if not in_sight and not alarmed:
				print("ALARM!!!")
				alarmed = true
				
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

func ragdoll():
	get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()
	get_node("RotationHelper/Character2").rotate_x(deg2rad(-50)) # to arrive at -90
	get_node("CollisionShape").disabled = true # only the ragdoll should be active
	
	dead = true

func die():
	#dead = true
	
	# tip him back
	get_node("RotationHelper/Character2").rotate_x(deg2rad(-40))
	# switch off animtree
	get_node("RotationHelper/Character2/AnimationTree").active = false
	# .. and IK
	$RotationHelper/Character2/Armature/rifleik.stop()
	$RotationHelper/Character2/Armature/left_ik.stop()
	
	#get_node("RotationHelper/Character2/Timer").start()
	
	# ragdoll
	# NOTE: ragdoll seems to break IF IK was used before, even if ik is stopped above
	ragdoll()
	
	#call_deferred("ragdoll")
	
	#get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()
	
	#get_node("RotationHelper/Character2").rotate_x(deg2rad(-50)) # to arrive at -90
	#get_node("CollisionShape").rotate_x(deg2rad(-90))
	#get_node("CollisionShape").disabled = true # only the ragdoll should be active
	
	# for AI, rotate the apparent aabb origin by 90 deg to fit the ragdoll
	#get_node("RotationHelper/Character2/Armature/HitBoxTorso/center").rotate_x(deg2rad(-90))
	
	#undo tipback (so that interacting later on works better)
	#get_node("RotationHelper/Character2").rotate_x(deg2rad(40))

func drop_gun():
	var hold = get_node("RotationHelper/Character2/Armature/WeaponHold")
	var gun = hold.get_node("Rifle2")
	var par = get_parent()
	
	if not gun:
		return # we already dropped it
	
	var gloc = gun.get_global_transform()
	
	# reparent
	hold.remove_child(gun)
	par.add_child(gun)
	# keep current pos
	gun.set_global_transform(gloc)
	# drop to ground
	var t = gun.get_translation()
	gun.set_translation(Vector3(t.x, 0.2, t.z))
	
	# IK
	$RotationHelper/Character2/Armature/rifleik.start()
	$RotationHelper/Character2/Armature/left_ik.start()
	
	# visible effect test
	#gun.rotate_x(deg2rad(-90))

# the position passed here is global
func _on_hurt(pos):
	if dead:
		return
	
	face_pos = pos

# AI targeting
func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		possible_tg = body


func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))


func _on_Timer_timeout():
	# haven't seen anyone, go back to normal
	face_pos = Vector3()
