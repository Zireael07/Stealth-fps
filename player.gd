extends KinematicBody

var player = true

const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 20
const JUMP_SPEED = 18
const ACCEL = 1 #4.5

var dir = Vector3()

const DEACCEL= 16
const MAX_SLOPE_ANGLE = 40

var camera
var camera_helper
var rotation_helper
var left_ik_tg

var MOUSE_SENSITIVITY = 0.05

var crouched = false

var state_machine

# Bullet impulse values are "artistic" according to a comment on gamedev.net
const PUSH_FORCE = 2 # has to be lower than OBJECT_THROW_FORCE below to make sense

var grabbed_object = null
var grabbed_previous_mode = null
const OBJECT_THROW_FORCE = 5
const VIS_OBJECT_GRAB_DISTANCE = 1
#const OBJECT_GRAB_RAY_DISTANCE = 10

var armed = true


func _ready():
	camera = $RotationHelper/Character/Armature/CameraBoneAttachment/Camera
	camera_helper = $RotationHelper/Character/Armature/HitBoxChest/Spatial # for ik targets
	rotation_helper = $RotationHelper
	
	left_ik_tg = camera_helper.get_node("left_ik_tg")
	
	state_machine = $RotationHelper/Character/AnimationTree
	
	# FPS input
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)
	camera.get_node("Spatial").detect_interactable()

func unwield():
	armed = false
	# unwield current weapon
	$CollisionShapeGun.disabled = true
	$RotationHelper/Character/Armature/WeaponHold/Rifle.hide()
	
	# proper animation for hands
	var g_pos = $RotationHelper/Character/Armature/WeaponHold/Rifle/Position3D.get_global_transform().origin #+ Vector3(0,0, 0.5)
	var lpos = camera_helper.to_local(g_pos)
	left_ik_tg.set_translation(Vector3(lpos.x, lpos.y-0.5, lpos.z))
	$RotationHelper/Character/Armature/left_ik.start()
	
	camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.65, 1, 1.75))
	camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(25, 90, 0)
	$RotationHelper/Character/Armature/rifleik.start()
	
	# update HUD
	get_node("Control/Center/Crosshair").hide()
	get_node("Control/Center/Control").show()


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
		if not armed:
			return
			
		camera.get_node("Spatial").fire_weapon()

	# Crouch
	if Input.is_action_just_pressed("movement_crouch"):
		# toggle
		crouched = not crouched
		if crouched:
			# crouching character is roughly 0.4 (1.7 to 1.3) lower
			$CollisionShape.set_translation(Vector3(0,0.527,0.324))
			$CollisionShape.get_shape().extents = Vector3(0.249, 0.52, 0.757)
			# change anim
			state_machine["parameters/move_state/playback"].travel("crouch")
		else:
			# restore original values
			$CollisionShape.set_translation(Vector3(0,0.927, 0.324))
			$CollisionShape.get_shape().extents = Vector3(0.249, 0.92, 0.757)
			state_machine["parameters/move_state/playback"].travel("run")


	# ----------------------------------
	if Input.is_action_just_pressed("interact"):
		# no interactable detected
		if grabbed_object == null and !camera.get_node("Spatial").last_interactable:
			# unwield guns
			if armed:
				unwield()
			else:
				armed = true
				# wield current weapon
				$CollisionShapeGun.disabled = false
				$RotationHelper/Character/Armature/WeaponHold/Rifle.show()
				
				# update HUD
				get_node("Control/Center/Crosshair").show()
				get_node("Control/Center/Control").hide()
				
			return
		
		# Case 1: grabbing items
		if grabbed_object == null:
			grabbed_object = camera.get_node("Spatial").last_interactable
			
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
				grabbed_object.get_node("RotationHelper/Character2").rotate_x(deg2rad(90))

		else:
			# throw the object
			if grabbed_object is RigidBody:
				grabbed_object.mode = RigidBody.MODE_RIGID

				grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE)
			if grabbed_object is KinematicBody:
				grabbed_object.carried = false
				# tipback trick again
				grabbed_object.get_node("RotationHelper/Character2").rotate_x(deg2rad(-90))
				# restart ragdoll
				grabbed_object.get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()

			grabbed_object.collision_layer = 1
			grabbed_object.collision_mask = 1

			grabbed_object = null

	if grabbed_object != null:
		var x_offset = camera.global_transform.basis.y.normalized() * -0.5
		
		if grabbed_object is KinematicBody:
			x_offset = Vector3(0,-1.5,0) # experimentally determined
		
		var z_offset = (-camera.global_transform.basis.z.normalized() * VIS_OBJECT_GRAB_DISTANCE)
		grabbed_object.global_transform.origin = camera.global_transform.origin + z_offset + x_offset
	
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
		if collision.collider.is_in_group("interactable"):
			collision.collider.apply_central_impulse(-collision.normal * PUSH_FORCE)
			
	if vel.length() > 0:
		state_machine["parameters/move_state/run/blend_position"] = Vector2(0,1) # actually animates leg movement
	else:
		state_machine["parameters/move_state/run/blend_position"] = Vector2(0,0) # stop moving

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		var rot = deg2rad(event.relative.y * MOUSE_SENSITIVITY)
		camera_helper.get_node("head_ik_tg").rotate_x(rot)
		$RotationHelper/Character/Armature/headik.start()
		
		# clamp now
		var view_rot = camera_helper.get_node("head_ik_tg").rotation_degrees 
		view_rot.x = clamp(view_rot.x, -70, 30) # above 30 we'd need special handling to avoid chest mesh clipping
		#print("Rot: ", view_rot.x)
		camera_helper.get_node("head_ik_tg").rotation_degrees = view_rot
		
		if not armed:
			return
			
		# this rotates everything, including our mesh and collision
		#rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		
		# rotate ik targets
		
		# rotate_x wants radians

		camera_helper.get_node("rifle_ik_tg").rotate_x(rot)

		# play ik
		$RotationHelper/Character/Armature/rifleik.start()
		#$RotationHelper/Character/Armature/left_ik.start()
		
		
		camera_helper.get_node("rifle_ik_tg").rotation_degrees = view_rot
		
		# this is tricky!
		var g_pos = $RotationHelper/Character/Armature/WeaponHold/Rifle/Position3D.get_global_transform().origin #+ Vector3(0,0, 0.5)
		var lpos = camera_helper.to_local(g_pos)
		left_ik_tg.set_translation(lpos)
		
		$RotationHelper/Character/Armature/left_ik.start()

#		var camera_rot = rotation_helper.rotation_degrees
#		camera_rot.x = clamp(camera_rot.x, -70, 50)
#		rotation_helper.rotation_degrees = camera_rot
