extends KinematicBody

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

func _ready():
	camera = $RotationHelper/Character/Armature/CameraBoneAttachment/Camera
	camera_helper = $RotationHelper/Character/Armature/HitBoxChest/Spatial # for ik targets
	rotation_helper = $RotationHelper
	
	left_ik_tg = camera_helper.get_node("left_ik_tg")
	
	# FPS input
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)

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
	if Input.is_action_pressed("shoot"):
		camera.get_node("Spatial").fire_weapon()

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
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# this rotates everything, including our mesh and collision
		#rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		
		# rotate ik targets
		var rot = deg2rad(event.relative.y * MOUSE_SENSITIVITY)
		
		# rotate_x wants radians
		camera_helper.get_node("head_ik_tg").rotate_x(rot)
		camera_helper.get_node("rifle_ik_tg").rotate_x(rot)

		# play ik
		$RotationHelper/Character/Armature/headik.start()
		$RotationHelper/Character/Armature/rifleik.start()
		#$RotationHelper/Character/Armature/left_ik.start()
		
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# clamp now
		var view_rot = camera_helper.get_node("head_ik_tg").rotation_degrees 
		view_rot.x = clamp(view_rot.x, -70, 30) # above 30 we'd need special handling to avoid chest mesh clipping
		#print("Rot: ", view_rot.x)
		camera_helper.get_node("head_ik_tg").rotation_degrees = view_rot
		camera_helper.get_node("rifle_ik_tg").rotation_degrees = view_rot
		
		# this is tricky!
		var g_pos = $RotationHelper/Character/Armature/WeaponHold/Rifle/Position3D.get_global_transform().origin #+ Vector3(0,0, 0.5)
		var lpos = camera_helper.to_local(g_pos)
		left_ik_tg.set_translation(lpos)
		
		$RotationHelper/Character/Armature/left_ik.start()

#		var camera_rot = rotation_helper.rotation_degrees
#		camera_rot.x = clamp(camera_rot.x, -70, 50)
#		rotation_helper.rotation_degrees = camera_rot
