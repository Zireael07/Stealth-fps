extends KinematicBody

var player = true

const GRAVITY = -24.8
var vel = Vector3()
var MAX_SPEED = 20 # depends on stance
var ACCEL = 1 #4.5
const JUMP_SPEED = 10 #18


var dir = Vector3()

const DEACCEL= 16
const MAX_SLOPE_ANGLE = 40

var camera
var camera_helper
var rotation_helper
var weapon_hold
var left_ik_tg

var MOUSE_SENSITIVITY = 0.05

# stances
const STANDING = 0
const CROUCHED = 1
const PRONE = 2
var stance = 0

var state_machine # anim state machine

# Bullet impulse values are "artistic" according to a comment on gamedev.net
const PUSH_FORCE = 2 # has to be lower than OBJECT_THROW_FORCE below to make sense

var grabbed_object = null
var grabbed_previous_mode = null
const OBJECT_THROW_FORCE = 5
const VIS_OBJECT_GRAB_DISTANCE = 1
#const OBJECT_GRAB_RAY_DISTANCE = 10

var scoping = false

# states (weapons)
const UNARMED = 0
const RIFLE = 1
const BATON = 2
const KNIFE = 3
var state = RIFLE
var prev_state = RIFLE

func _ready():
	camera = $RotationHelper/Character/Armature/CameraBoneAttachment/Camera
	weapon_hold = $RotationHelper/Character/Armature/WeaponHold/
	camera_helper = $RotationHelper/Character/Armature/HitBoxChest/Spatial # for ik targets
	rotation_helper = $RotationHelper
	
	left_ik_tg = camera_helper.get_node("left_ik_tg")
	
	state_machine = $RotationHelper/Character/AnimationTree
	
	# FPS input
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_node("Control/scoring").hide()
	
	# enable IK
	$RotationHelper/Character/Armature/left_ik.start()
	$RotationHelper/Character/Armature/rifleik.start()
	$RotationHelper/Character/Armature/headik.start()

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)
	camera.get_node("Spatial").detect_interactable()

func left_hand_empty_ik():
	var g_pos = $RotationHelper/Character/Armature/WeaponHold/Rifle2/Position3D.get_global_transform().origin #+ Vector3(0,0, 0.5)
	var lpos = camera_helper.to_local(g_pos)
	left_ik_tg.set_translation(Vector3(lpos.x, lpos.y-0.5, lpos.z))
	#$RotationHelper/Character/Armature/left_ik.start()


func unwield():
	# unwield current weapon
	$CollisionShapeGun.disabled = true	
	prev_state = state
	state = UNARMED
	
	# proper animation for hands
	left_hand_empty_ik()
	
	camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.65, 1, 1.75))
	camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(25, 90, 0)
	#$RotationHelper/Character/Armature/rifleik.start()
	
	# update HUD
	get_node("Control/Center/Crosshair").hide()
	get_node("Control/Center/Control").show()


func wield_again():
	state = prev_state
	# wield current weapon
	$CollisionShapeGun.disabled = false
	if state == RIFLE:
		weapon_hold.get_node("Rifle2").show()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Knife").hide()
	elif state == BATON:
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").show()
		weapon_hold.get_node("Knife").hide()
		left_hand_empty_ik()
	elif state == KNIFE:
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Knife").show()
		weapon_hold.get_node("Baton").hide()
		left_hand_empty_ik()
	
	# restore the previous right hand IK
	# these are the initial values upon game start
	camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.65, 2.2, 1.75))
	camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(0, 0, 0)
	#$RotationHelper/Character/Armature/rifleik.start()
	
	
	# update HUD
	get_node("Control/Center/Crosshair").show()
	get_node("Control/Center/Control").hide()


func process_input(delta):

	# ----------------------------------
	# Walking
	# Based on the action pressed, we move in a direction relative to the camera.
	
	# Reset dir, so our previous movement does not effect us
	dir = Vector3()
	# Get the camera's global transform so we can use its directional vectors
	var cam_xform = camera.get_global_transform()
	# Create a vector for storing our keyboard/joypad input
	var input_movement_vector = Vector2()
	# Keyboard input
	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	# Normalize the input movement vector so we cannot move too fast
	input_movement_vector = input_movement_vector.normalized()

	# Add the camera's local vectors based on what direction we are heading towards.
	# NOTE: because the camera is rotated by -180 degrees
	# all of the directional vectors are the opposite in comparison to our KinematicBody.
	# (The camera's local Z axis actually points backwards while our KinematicBody points forwards)
	# To get around this, we flip the camera's directional vectors so they point in the same direction

	# Basis vectors are already normalized.
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x
	# ----------------------------------

	# ----------------------------------
	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("movement_jump"):
			vel.y = JUMP_SPEED
	# ----------------------------------

	# ----------------------------------
	# Firing the weapons
	if Input.is_action_just_pressed("shoot"):
		if state == UNARMED:
			wield_again()
			return
		
		if state == BATON:
			camera.get_node("Spatial").melee_weapon(true)
		elif state == KNIFE:
			camera.get_node("Spatial").melee_weapon(false)
		else:
			camera.get_node("Spatial").fire_weapon()
		
	if Input.is_action_just_pressed("shoot_alt"):
		if not state == RIFLE:
			return
			
		if not scoping:
			scoping = true
			$RotationHelper/Character/Armature/WeaponHold/Rifle2/Sight/AimCamera.current = true
		else:
			camera.current = true
			scoping = false

	# Crouch
	if Input.is_action_just_pressed("movement_crouch"):
		if stance == PRONE:
			print("Back to standing")
			stance = 0
		else:
			# toggle
			stance += 1
			#print("Stance ", stance)

		if stance == CROUCHED:
			MAX_SPEED = 15
			ACCEL = 0.5
			# crouching character is roughly 0.4 (1.7 to 1.3) lower
			$CollisionShape.set_translation(Vector3(0,0.527,0.324))
			$CollisionShape.get_shape().extents = Vector3(0.249, 0.52, 0.757)
			# change anim
			state_machine["parameters/move_state/playback"].start("crouch")
		elif stance == STANDING:
			MAX_SPEED = 20
			ACCEL = 1
			$RotationHelper/Character/Armature/rifleik2.stop()
			$RotationHelper/Character/Armature/left_ik2.stop()
			# restore original values that prone changes
			$RotationHelper/Character.set_rotation_degrees(Vector3(0, 0, 0))
			$RotationHelper/Character.set_translation(Vector3(0, 0, 0))
			$CollisionShape.set_rotation_degrees(Vector3(0,0,0))
			#$CollisionShape.set_translation(Vector3(0,0.927,0.15))
			camera_helper.get_node("head_ik_tg").rotation_degrees = Vector3(0, 0, 0)
			camera_helper.set_translation(Vector3(-0.014, -0.026, 1.244))
			# these are the original values
			camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.65, 2.2, 1.75))
			camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(0,0,0)
			# unfortunately doesn't quite work
			#$RotationHelper/Character/Armature/rifleik.root_bone = "LowerArm.R"
			#$RotationHelper/Character/Armature/left_ik.root_bone = "LowerArm.R"
			$RotationHelper/Character/Armature/rifleik.start()
			$RotationHelper/Character/Armature/left_ik.start()
			
			# standing
			$CollisionShape.set_translation(Vector3(0,0.927, 0.324))
			$CollisionShape.get_shape().extents = Vector3(0.249, 0.92, 0.757)
			state_machine["parameters/move_state/playback"].start("run")
		elif stance == PRONE:
			MAX_SPEED = 10
			ACCEL = 0.25
			$RotationHelper/Character.set_rotation_degrees(Vector3(90, 0, 0))
			$RotationHelper/Character.set_translation(Vector3(1, 0, -1))
			$CollisionShape.set_rotation_degrees(Vector3(90,0,0))
			$CollisionShape.set_translation(Vector3(1, 0, 0))
			$CollisionShape.get_shape().extents = Vector3(0.249, 0.95, 0.757)
			# no animations yet
			
			$RotationHelper/Character/Armature/left_ik.stop()
			$RotationHelper/Character/Armature/rifleik.stop()
			# adjust IK targets
			camera_helper.set_translation(Vector3(-1.66, -1.7, -0.8))
			camera_helper.get_node("head_ik_tg").rotation_degrees = Vector3(-85, 0, 0)
			$RotationHelper/Character/Armature/headik.start()
			# hackfix to stop arm obscuring our view
			camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.15, 2.2,1.75))
			camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(-90,0,0)
			# we need to move the upper arms in prone position, too
			#$RotationHelper/Character/Armature/rifleik.root_bone = "UpperArm.R"
			$RotationHelper/Character/Armature/rifleik2.start()
			$RotationHelper/Character/Armature/left_ik2.start()

	# --------------------------------------
	# weapon switching
	if Input.is_action_just_pressed("weapon_1"):
		state = RIFLE
		weapon_hold.get_node("Rifle2").show()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Knife").hide()
	if Input.is_action_just_pressed("weapon_2"):
		state = BATON
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").show()
		weapon_hold.get_node("Knife").hide()
		left_hand_empty_ik()
	if Input.is_action_just_pressed("weapon_3"):
		state = KNIFE
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Knife").show()
		left_hand_empty_ik()

	# ----------------------------------
	if Input.is_action_just_pressed("interact"):
		# go back to normal cam
		camera.current = true
		
		# no interactable detected
		if grabbed_object == null and !camera.get_node("Spatial").last_interactable:
			# unwield guns
			if state != UNARMED:
				unwield()
			else:
				wield_again()
				
			return
		
		# Case 1: grabbing items
		if grabbed_object == null:
			var inter = camera.get_node("Spatial").last_interactable
			
			# if it's a static object, run its function instead
			if inter.is_in_group("static"):
				inter._on_interact()
				return 
					
			grabbed_object = inter
			# clear interactable
			#camera.get_node("Spatial").last_interactable = null
			
			# unwield any weapons
			unwield()
			
			# grab it
			if grabbed_object is RigidBody:
				grabbed_object.mode = RigidBody.MODE_STATIC

			grabbed_object.collision_layer = 0
			grabbed_object.collision_mask = 0
			
			if grabbed_object is KinematicBody:
				grabbed_object.carried = true
				#stop the ragdoll
				grabbed_object.get_node("RotationHelper/Character2/Armature").physical_bones_stop_simulation()
				grabbed_object.get_node("RotationHelper/Character2").set_rotation(Vector3(deg2rad(0), 0, 0))

		else:
			# are we aiming at another interactable?
			if camera.get_node("Spatial").last_interactable:
				#print("Aiming at interactable...")
				
				# get interactable's mesh aabb
				var mesh = camera.get_node("Spatial").last_interactable.get_child(1)
				var origin = mesh.get_global_transform().origin
				var end_point = mesh.get_aabb().end
				var siz = mesh.get_aabb().size
				
				var gl = origin + end_point + Vector3(-siz.x/2,0.2,-siz.y/2) # slightly above the surface
				grabbed_object.global_transform.origin = gl
				
				# reenable physics to prevent weirdness like things clipping into each other
				if grabbed_object is RigidBody:
					grabbed_object.mode = RigidBody.MODE_RIGID
				
			else:
				# throw the object
				if grabbed_object is RigidBody:
					grabbed_object.mode = RigidBody.MODE_RIGID

					grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)
					
					# if it's a grenade, arm it
					if grabbed_object.is_in_group("grenade"):
						grabbed_object.armed = true
						grabbed_object.get_node("Timer").start()
						grabbed_object.get_node("Area").collision_layer = 1
						grabbed_object.get_node("Area").collision_mask = 1
			
			# make the ragdoll work again
			if grabbed_object is KinematicBody:
				grabbed_object.carried = false
				
				grabbed_object.get_node("RotationHelper/Character2/Armature/Physical Bone Torso").apply_impulse(Vector3(0,0,0), -camera.global_transform.basis.z.normalized() * 1.5)

				# tipback trick again
				#grabbed_object.get_node("RotationHelper/Character2").set_rotation(Vector3(deg2rad(-90), 0, 0))
				#grabbed_object.get_node("RotationHelper/Character2").rotate_x(deg2rad(-90))
				
				# restart ragdoll
				grabbed_object.get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()

			# make it collide again
			grabbed_object.collision_layer = 1
			grabbed_object.collision_mask = 1

			grabbed_object = null

	if grabbed_object != null:
		var rotation = global_transform.basis.get_euler()
		
		var x_offset = camera.global_transform.basis.y.normalized() * -0.5
		
		if grabbed_object is KinematicBody:
			x_offset = Vector3(0,-1.5,0) # experimentally determined
		
		var z_offset = (-camera.global_transform.basis.z.normalized() * VIS_OBJECT_GRAB_DISTANCE)
		
		grabbed_object.global_transform.origin = camera.global_transform.origin + z_offset + x_offset
		grabbed_object.rotation = rotation
	
	# ----------------------------------
	# Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# ----------------------------------

# Process our movements (influenced by our input) and sending them to KinematicBody
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
	# Interpolate our velocity (without gravity), and then move using move_and_slide
	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	# infinite inertia is now false for better physics when colliding with objects
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE), false)
	#print("Vel: ", vel)
	
	# https://kidscancode.org/godot_recipes/physics/kinematic_to_rigidbody/
	# after calling move_and_slide()
	for index in get_slide_count():
		var collision = get_slide_collision(index)
		if collision.collider.is_in_group("interactable") and collision.collider is RigidBody:
			collision.collider.apply_central_impulse(-collision.normal * PUSH_FORCE)
		if collision.collider.is_in_group("crate"):
			var cr_imp = -camera.global_transform.basis.z.normalized() * PUSH_FORCE/3
			print("Collided with crate, imp: ", Vector3(cr_imp.x, 0, cr_imp.z))
			collision.collider.apply_impulse(Vector3(0,-2,0), Vector3(cr_imp.x, 0, cr_imp.z))
			
	if vel.length() > 0 and stance != PRONE:
		state_machine["parameters/move_state/run/blend_position"] = Vector2(0,1) # actually animates leg movement
		state_machine["parameters/move_speed/scale"] = 1.2
	else:
		state_machine["parameters/move_state/run/blend_position"] = Vector2(0,0) # stop moving
		# stop the headbob
		state_machine["parameters/move_speed/scale"] = 0

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		var rot = deg2rad(event.relative.y * MOUSE_SENSITIVITY)
		camera_helper.get_node("head_ik_tg").rotate_x(rot)
		#$RotationHelper/Character/Armature/headik.start()
		
		# clamp now
		var view_rot = camera_helper.get_node("head_ik_tg").rotation_degrees 
		
		if stance != PRONE:
			view_rot.x = clamp(view_rot.x, -70, 30) # above 30 we'd need special handling to avoid chest mesh clipping
		else:
			view_rot.x = clamp(view_rot.x, -100, -70)
			#print("Rot: ", view_rot.x)
		camera_helper.get_node("head_ik_tg").rotation_degrees = view_rot
		
		if state != RIFLE:
			return
			
		# this rotates everything, including our mesh and collision
		#rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		
		# rotate ik targets
		# rotate_x wants radians
		if stance != PRONE:
			camera_helper.get_node("rifle_ik_tg").rotate_x(rot)

			camera_helper.get_node("rifle_ik_tg").rotation_degrees = view_rot
			# play ik
#			$RotationHelper/Character/Armature/rifleik.start()
#		else:
#		#	camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(-90,0,0)
#			$RotationHelper/Character/Armature/rifleik2.start()
	
		# this is tricky!
		var g_pos = $RotationHelper/Character/Armature/WeaponHold/Rifle2/Position3D.get_global_transform().origin #+ Vector3(0,0, 0.5)
		var lpos = camera_helper.to_local(g_pos)
		left_ik_tg.set_translation(lpos)
	
		if stance == PRONE:
			left_ik_tg.translate(Vector3(0.75, 0,0))
		
#			$RotationHelper/Character/Armature/left_ik2.start()
#		else:	
#			$RotationHelper/Character/Armature/left_ik.start()

# ---------------------------------------------
func _on_gadget_mode(index):
	if index < 2:
		for c in get_tree().get_nodes_in_group("AI"):
			c._on_thermal_vision(false)
	
	if index == 0:
		get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment.adjustment_enabled = false
	elif index == 1:
		# turn nightvision on
		get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment.adjustment_enabled = true
	elif index == 2:
		get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment.adjustment_enabled = false
		# thermal effect
		for c in get_tree().get_nodes_in_group("AI"):
			c._on_thermal_vision(true)
