extends KinematicBody


# Declare member variables here. Examples:
export var nav: NodePath = "/root/Spatial/nav"
var possible_tg = null

var dead = false
var carried = false
var unconscious = false

var brain

var in_sight = false

# see player.gd - this is the anim state machine
var state_machine

const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 2 #10 #20 # in m/s - 4 m/s is a human walking speed
const JUMP_SPEED = 18
const ACCEL = 2 #4 #4.5

var dir = Vector3()
var prev_dirs = []
var _brain_st = Vector2()

const DEACCEL= 4 #10 #16
const MAX_SLOPE_ANGLE = 40

var STEER_SENSITIVITY = 0.5 #0.05
var strafe = false

var target_array = []
var current = 0
var prev = 0

var alarmed = false
var grenade_threat = null

var face_pos = Vector3()
var timetospot = 1.0 # brief research seems to indicate anything between 0.3 to 1.5 is realistic
var last_seen_pos = Vector3()

var player = null
var draw = null
var elapsed_sec = 0

# context steering
export var num_rays = 16
var interest = []
var danger = []
var chosen_dir = Vector3.ZERO
var context_has_danger = false

var mesh = null

# material
var camo = preload("res://assets/camo_triplanar_mat.tres")
var thermal = preload("res://assets/thermal_vis_material.tres")
var optic_camo = preload("res://assets/optic_camo_material.tres")

signal emit_bark

# allies
signal enemy_seen

export var debug = false

# emotes
var hostile_emote = preload("res://assets/kenney_emotes/emote_exclamations.png")
var alarmed_emote = preload("res://assets/kenney_emotes/emote_exclamation.png")
var cantsee_emote = preload("res://assets/kenney_emotes/emote_cross.png")
var seen_emote = preload("res://assets/kenney_emotes/emote_dots2.png")
var think_emote = preload("res://assets/kenney_emotes/emote_circle.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	# b/c it's placed in global space
	get_node("MeshInstance").set_as_toplevel(true)
	if has_node("MeshInstance2"):
		get_node("MeshInstance2").set_as_toplevel(true)
	#get_node("RotationHelper/Character2/Timer").connect("timeout", self, "ragdoll")
	
	player = get_tree().get_nodes_in_group("player")[0]
	
	connect("emit_bark", player, "_on_emit_bark")
	connect("enemy_seen", self, "_on_enemy_seen")
	connect("enemy_seen", player, "on_enemy_seen")
	
	# context steering
	interest.resize(num_rays)
	danger.resize(num_rays)
	add_rays()
	
	mesh = get_node("RotationHelper/Character2/Armature/Body")
	if is_in_group("civilian"):
		mesh = get_node("RotationHelper/model/Human Armature/Skeleton/Human_Mesh")
		if not mesh:
			# head because we merge it with legs later to get the whole lot
			mesh = get_node("RotationHelper/model/CharacterArmature/Skeleton/Suit_Head") 
	
	state_machine = $RotationHelper/Character2/AnimationTree
	
	if is_in_group("boss"):
		# feet
		get_node("RotationHelper/model/CharacterArmature/Skeleton/SkeletonIK").start()
		get_node("RotationHelper/model/CharacterArmature/Skeleton/SkeletonIK2").start()
		# legs
		get_node("RotationHelper/model/CharacterArmature/Skeleton/SkeletonIK3").start()
		get_node("RotationHelper/model/CharacterArmature/Skeleton/SkeletonIK4").start()
	
	brain = $brain
	
	# get points
	# get_tree().get_nodes_in_group("root")[0]
	if get_node(nav):
		for c in get_node(nav).get_children():
			target_array.append(c)
		#brain.target = get_parent().get_node("nav").get_child(0)
		brain.target = target_array[0]
	
	# debug helpers
	draw = player.get_node("Control/DebugDraw")
	if debug:
		register_debugging_lines()
	
	
	# fake aabb for outlines
	var aabb_center = $RotationHelper/Character2/Armature/HitBoxTorso/center
	var scale = Vector3(1,1,1)
	if is_in_group("civilian"):
		aabb_center = $"RotationHelper/model/Position3D"
		if not is_in_group("boss"):
			scale = Vector3(0.35, 0.35, 0.35)
	
	for i in range(7):
		var end_point = mesh.get_aabb().get_endpoint(i) * scale # local space
		if is_in_group("boss"):
			end_point = mesh.get_aabb().merge(get_node("RotationHelper/model/CharacterArmature/Skeleton/Suit_Legs").get_aabb()).get_endpoint(i)
			
		 # because we're looking at relative to center
		var point = to_global(end_point)
		var pt = Position3D.new()
		#var msh = CubeMesh.new()
		#msh.size = Vector3(0.25, 0.25, 0.25)
		#var pt = MeshInstance.new()
		#pt.set_mesh(msh)
		aabb_center.add_child(pt)
		pt.global_transform.origin =  point


	if not is_in_group("civilian"):
		var ray = $RotationHelper/Area/RayCast
	
		# exclude all of our own bones so that we can't shoot ourselves
		var bones = [$RotationHelper/Character2/Armature/HitBoxHead/Area, $RotationHelper/Character2/Armature/HitBoxNeck/Area, $RotationHelper/Character2/Armature/HitBoxChest/Area,
	$RotationHelper/Character2/Armature/HitBoxTorso/Area, $RotationHelper/Character2/Armature/HitBoxPelvis/Area, 
	$RotationHelper/Character2/Armature/HitBoxUpperArmL/Area, $RotationHelper/Character2/Armature/HitBoxLowerArmL/Area, $RotationHelper/Character2/Armature/HitBoxLowerArmR/Area, $RotationHelper/Character2/Armature/HitBoxUpperArmR/Area
	]
	
		for b in bones:
			ray.add_exception(b)


	# the sniper drops prone immediately
	if get_name() == "sniper":
		brain.set_state(brain.STATE_IDLE)
		get_node("Timer2").start()
		# the changes mean we're roughly 0.7 units tall (Z value)
		$RotationHelper/Character2.set_rotation_degrees(Vector3(90, 0, 0))
		$RotationHelper/Character2.set_translation(Vector3(1, 0, -1))
		$CollisionShape.set_rotation_degrees(Vector3(90,0,0))
		$CollisionShape.set_translation(Vector3(1, 0, 0))
		$CollisionShape.get_shape().extents = Vector3(0.249, 0.95, 0.757)
		#$"CollisionShapeGun".set_translation(Vector3(-0.205, 0, 0.95))
		# rotate the head
		state_machine["parameters/look/blend_position"] = Vector2(0, 0.5)  # 1 is 90 degrees
		# fix vision cone to match
		$RotationHelper/Area.global_transform.origin = $RotationHelper/Character2/Armature/HitBoxHead.global_transform.origin
		$RotationHelper/Area.translate(Vector3(0,0.5,-0.5)) # fudge to match rotated head
		$RotationHelper/Area.rotation = Vector3(0.5,0, 0)
		# aim the gun
		var camera_helper = $RotationHelper/Character2/Armature/HitBoxChest/Spatial
		camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.15, 2.2,1.75))
		camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(-40,0,0)
		# we need to move the upper arms in prone position, too
		camera_helper.get_node("left_ik_tg").set_translation(Vector3(0.15, 2.2,1.75))
		$RotationHelper/Character2/Armature/rifleik.start()
		$RotationHelper/Character2/Armature/left_ik.start()
		# move visual indicator to above character's head
		get_node("RotationHelper/MeshInstance").global_transform.origin = $RotationHelper/Character2/Armature/HitBoxHead.global_transform.origin
		get_node("RotationHelper/MeshInstance").translate(Vector3(0,0.75, -0.2))

#- ----------------------------
func add_rays():
	var angle = 2 * PI / num_rays
	for i in num_rays:
		var r = RayCast.new()
		$ContextRays.add_child(r)
		if i == 0 or i == 1 or i == num_rays-1:
			r.cast_to = Vector3.FORWARD * 1
		else:
			r.cast_to = Vector3.FORWARD * 1
		r.rotation.y = -angle * i
		r.add_exception(self)
		r.enabled = true
		# debug
		#rays[i] = (r.cast_to.normalized()*4).rotated(Vector3(0,1,0), r.rotation.y)
	#forward_ray = $ContextRays.get_child(0)


# debugging
func register_debugging_lines():
	if draw != null:
		var pos = get_global_transform().origin
		var end = brain.target
		draw.add_line(self, pos, end, 3, Color(0,0,1)) # blue
		
		draw.add_line(self, pos, to_global(Vector3(brain.velocity.x, 0, brain.velocity.y)), 3, Color(1,1,0)) # yellow
		draw.add_line(self, pos, to_global(Vector3(brain.steer.x, 0, brain.steer.y)), 3, Color(1,0,0)) # red
		draw.add_line(self, pos, to_global(Vector3(brain.desired.x, 0, brain.desired.y)), 3, Color(1,0,1)) # purple

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#elapsed_sec = elapsed_sec + delta
#	#if elapsed_sec > 2.0:
#		if is_in_group("ally"):
#			register_debugging_lines()
		if !debug:
			return
			
		var _tg = brain.target
		if brain.target == null or !is_instance_valid(brain.target):
			return
		
		if not typeof(brain.target) == TYPE_VECTOR3:
			_tg = brain.target.global_transform.origin
			
		# debugging
		if get_viewport().get_camera().get_name() == "TopDownCamera":
			draw.update_line(self, 0, get_global_transform().origin, _tg)
			draw.update_line(self, 1, get_global_transform().origin, to_global(Vector3(brain.velocity.x, 0, brain.velocity.y)))
			draw.update_line(self, 2, get_global_transform().origin, to_global(Vector3(brain.steer.x, 0, brain.steer.y)))
			draw.update_line(self, 3, get_global_transform().origin, to_global(Vector3(brain.desired.x, 0, brain.desired.y)))
	#	pass

# ---------------------------------------------
func dist_to_target():
	# paranoia
	if not brain.target or brain.target == null or !is_instance_valid(brain.target):
		return 0
		
	var loc = to_local(brain.target.get_global_transform().origin)
	var dist = Vector2(loc.x, loc.z).length()
	return dist

func is_close_to_target(rang=1):
	var ret = false
	var loc = brain.target
	if not typeof(brain.target) == TYPE_VECTOR3:
		loc = to_local(brain.target.get_global_transform().origin)
	else: 
		loc = to_local(brain.target)
	var dist = Vector2(loc.x, loc.z).length()
	if dist <= rang:
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
	
	# hackfix for getting stuck
	# keep a rolling window of previous three steers
	# inspired by https://markdownpastebin.com/?id=d9d61e67f9d64db2bd215f165b931449 which uses something similar for on_floor()
	if prev_dirs.size() < 3:
		prev_dirs.append(dir)
	else:
		# remove the first entry
		prev_dirs.remove(0)
		prev_dirs.append(dir)
	
	# check
	var flipping = false
	if prev_dirs.size() == 3:
		flipping = prev_dirs[0].dot(prev_dirs[1]) < 0 and prev_dirs[1].dot(prev_dirs[2]) < 0
		if flipping:
			#print("Flipping!")
			if chosen_dir == Vector3.ZERO:
				# fix? take the middle one
				dir = prev_dirs[1] 
#			else:
#				# if we have a chosen_dir, we want to avoid obstacles... so it's most important
#				dir = chosen_dir

	# determine where we want to go
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
	
	if flipping:
		accel = DEACCEL*2
		
	# Interpolate our velocity (without gravity), and then move using move_and_slide
	hvel = hvel.linear_interpolate(target, accel * delta)
	#if debug: print("Interp: ", accel*delta)
	# Boost for very low speeds
	if hvel.length() < 0.5:
		hvel = hvel*1.25
	
	vel.x = hvel.x 
	#vel.x = 0 # eliminate drift since AI can't strafe
	vel.z = hvel.z
	# infinite inertia is now false for better physics when colliding with objects
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE), false)
	#if debug: print("V: ", vel, " sp: ", vel.length())
	
	# debug
	get_node("MeshInstance").set_translation(global_transform.origin+Vector3(vel.x, 0, vel.z))
	# transform global velocity to local
	var loc_vel = to_local(global_transform.origin+vel)
	
	# x is turning and y is forward/backwards
	var _vel_x = 0
	if strafe:
		_vel_x = loc_vel.x
	brain.velocity = Vector2(_vel_x, loc_vel.z) #vel.length())
	
	# https://kidscancode.org/godot_recipes/physics/kinematic_to_rigidbody/
	# after calling move_and_slide()
	for index in get_slide_count():
		var collision = get_slide_collision(index)
		if collision.collider.is_in_group("interactable") and collision.collider is RigidBody:
			collision.collider.apply_central_impulse(-collision.normal * 2)

func move(delta):
	#if debug: print("Moving!")
	# state sets the steer/rotations used below
	brain.state.update(delta)
	_brain_st = brain.steer
	
	# context steering
	context_has_danger = false
	chosen_dir = Vector3.ZERO
	set_danger()
	# only do stuff if we need to (if we detected danger)
	if context_has_danger:
		set_interest_steer()
		merge_direction()
		choose_direction()
		
		#debug
		#get_node("MeshInstance").set_translation(global_transform.origin+Vector3(chosen_dir.x, 0, chosen_dir.z))
		
		#print("Steer: ", brain.steer, ", chosen_dir: ", chosen_dir)
		# chosen_dir is GLOBAL!!!
		brain.steer = brain.seek(global_transform.origin + Vector3(chosen_dir.x, 0, chosen_dir.z))
		#print("Steer post adjustment ", brain.steer)
	
	#brain.steer = brain.arrive(brain.target, 5)
	# rotations if any
	#self.rotate_y(deg2rad(brain.steer.x * STEER_SENSITIVITY))  #* -1))
	
	
	# Reset dir, so our previous movement does not affect us
	dir = Vector3()
	
	# Create a vector for storing input
	var input_movement_vector = Vector2()
	if not strafe:
		# steer y means forward/backwards
		if brain.steer.y > 0:
			input_movement_vector.y += 1
		if brain.steer.y < 0:
			input_movement_vector.y += -1
		
	if strafe:
		# actual movement
		if brain.steer.x < 0:
			input_movement_vector.x -= clamp(abs(brain.steer.x), 0, 1)
		if brain.steer.x > 0:
			input_movement_vector.x += clamp(abs(brain.steer.x), 0, 1)
		
		if brain.steer.y > 0:
			input_movement_vector.y += clamp(abs(brain.steer.y), 0, 1)
		if brain.steer.y < 0:
			input_movement_vector.y += -clamp(abs(brain.steer.y), 0, 1)
			
	#print("input: ", input_movement_vector)
	
	# Normalize the input movement vector so we cannot move too fast
	input_movement_vector = input_movement_vector.normalized()
	
	#print("AI input vec:", input_movement_vector)
	
	# Basis vectors are already normalized.
	dir = get_global_transform().basis.z * input_movement_vector.y
	if strafe:
		var _dir = dir + get_global_transform().basis.x * input_movement_vector.x
		dir = Vector3(_dir.x, dir.y, dir.z) 
		#print("dir after strafe")
	
	process_movement(delta)

# ------------------------------------------------------------
# based on Kidscancode's https://kidscancode.org/godot_recipes/ai/context_map/
func set_interest_steer():
	# Go forward unless we have somewhere to steer
	var path_direction = transform.basis.z
	
	# see line 313
	if _brain_st != Vector2.ZERO:
		# convert steer to global direction
		# Basis vectors are already normalized.
		var global_steer_dir = get_global_transform().basis.z * _brain_st.y
		if strafe:
			global_steer_dir += get_global_transform().basis.x * _brain_st.x
			
		path_direction = global_steer_dir
		
		#get_node("MeshInstance2").set_translation(global_transform.origin+path_direction)
		
	for i in num_rays:
		var d = -$ContextRays.get_child(i).global_transform.basis.z
		d = d.dot(path_direction)
		interest[i] = max(0, d)


func set_danger():
	for i in num_rays:
		var ray = $ContextRays.get_child(i)
		danger[i] = 1.0 if ray.is_colliding() else 0.0
		if danger[i] > 0.0:
			context_has_danger = true

func merge_direction():
	for i in num_rays:
		if danger[i] > 0.0:
			# danger "poisons" neighboring directions
			if i-1 > 0:
				interest[i-1] = 0.05
			if i+1 < num_rays:
				interest[i+1] = 0.05
			
			# zero any interest in dangerous directions
			interest[i] = 0.0
			
			# front rays add interest to the side
			if i == 0 or i == 1 or i == 2:
				# x-(x/4) is to the left
				# adding means we won't get stuck if all or most front rays encounter something
				interest[num_rays-(num_rays/4)] += 2.0*danger[i]
			if i == num_rays-1 or i == num_rays-2:
				# num_rays/4 is to the right
				# see above
				interest[num_rays/4] += 2.0*danger[i]
				
				
			
			# add interest in opposite direction
			if i < num_rays/2:
				interest[i+num_rays/2] = 5
			else:
				interest[i-num_rays/2] = 5
			
			
func choose_direction():
	chosen_dir = Vector3.ZERO
	for i in num_rays:
		# this is GLOBAL!!!!
		chosen_dir += -$ContextRays.get_child(i).global_transform.basis.z * interest[i]
	chosen_dir = chosen_dir.normalized()

# ------------------------------------------------
# this is where most of the AI action takes place
func _physics_process(delta):	
	if not carried and (dead or unconscious):
		# attempt to sync collision with ragdoll
		global_transform.origin = get_node("RotationHelper/Character2/Armature/HitBoxPelvis/Area/CollisionShape").global_transform.origin
		return
	
	if not dead and not unconscious:
		if get_name() == "sniper":
			# look around
			if not in_sight and get_node("Timer2").time_left > 0 and not brain.get_state() == brain.STATE_ALARMED and not brain.get_state() == brain.STATE_DISENGAGE:
				#print("Sniper looks around...")
				#print("Timer's on, ", get_node("Timer2").time_left)
				var w = get_node("Timer2").time_left/2.0 # 2 is the total timer
				#print("lerp weight: ", w)
				var look_at = lerp(Vector2(-0.5, 0.5), Vector2(0.5, 0.5), w) # different for sniper
				#print("Look at: ", look_at.x)
				var rot = lerp(-45, 45, w)
				state_machine["parameters/look/blend_position"] = look_at
				# adjust vision cone to match
				$RotationHelper/Area.rotation_degrees = Vector3(rad2deg(0.5),rot,0) # nullify any previous

		# animate movement
		if state_machine:
			if vel.length() > 0:
				state_machine["parameters/move_state/run/blend_position"] = Vector2(0,1) # actually animates leg movement
			else:
				state_machine["parameters/move_state/run/blend_position"] = Vector2(0,0) # stop moving
		
		# special cases
		if is_in_group("civilian"):
			brain.set_state(brain.STATE_IDLE)
			return
			
		if is_in_group("ally"):
			if not player.talking:
				if brain.get_state() == brain.STATE_FOLLOW:
					# stay "a step behind" the player
					# TODO: the x offset could be randomized or depend on direction to obstacles/enemies
					brain.target = player.get_global_transform().xform(Vector3(1, 0, -3))
				elif brain.get_state() == brain.STATE_IDLE:
					pass
				else:
					brain.set_state(brain.STATE_FOLLOW)
				
				# debug
				if brain.target != null and is_instance_valid(brain.target):
					if typeof(brain.target) == TYPE_VECTOR3:
						get_node("MeshInstance2").set_translation(brain.target)
					else:
						get_node("MeshInstance2").set_translation(brain.target.get_global_transform().origin)
				#return
			#elif hold: brain.set_state(brain.STATE_IDLE)
			else:
				# only do it once
				if brain.get_state() != brain.STATE_IDLE:
					brain.set_state(brain.STATE_IDLE)
					# look at the player while talking to him
					look_at(player.global_transform.origin, Vector3(0,1,0))
					# because this looks the opposite way for some reason
					rotate_y(deg2rad(180))
				return

		# AI behaviors start here
		# TODO: move some/most of this to brain.gd?
		
		if grenade_threat:
			
			if grenade_threat != null and is_instance_valid(grenade_threat):
				# is it in direct sight (not behind a wall)
				# Get the raycast node
				var ray = $RotationHelper/Area/RayCast
				ray.collision_mask = 1
				ray.collide_with_areas = false
				
				# set the proper cast_to
				ray.cast_to = ray.to_local(grenade_threat.get_global_transform().origin) #*1.5
				
				# Force the raycast to update. This will force the raycast to detect collisions when we call it.
				# This means we are getting a frame perfect collision check with the 3D world.
				ray.force_raycast_update()

				# Did the ray hit something?
				if ray.is_colliding() and ray.get_collider() == grenade_threat:
					if timetospot > 0:
						timetospot = timetospot- delta*2
						#print("Timetospot: ", timetospot)
					if timetospot <= 0 and grenade_threat != null:
						if brain.get_state() != brain.STATE_AVOID_GREN:
							brain.set_state(brain.STATE_AVOID_GREN, grenade_threat)
							brain.target = grenade_threat
							emit_signal("emit_bark", self, "Saw a 'nade!")
							return
				else:
					print("Grenade behind a wall")
		
		# if we're unarmed, disengage
		if !is_armed() and in_sight and possible_tg != null:
			#print(get_name() + " state is: " + str(brain.pretty_states[brain.get_state()]))
			if brain.get_state() != brain.STATE_DISENGAGE:
				emit_signal("emit_bark", self, "Discretion is the better part of valor!")
				brain.set_state(brain.STATE_DISENGAGE)
				brain.target = possible_tg
				return
		

		if !is_armed() and in_sight: # not in_sight is handled further down
			# movement
			move(delta)
		
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
			# paranoia
			#if target_array == null or target_array.size() < 1:
			#	return
			
			# for now, snipers don't move
			if get_name() != "sniper":
				# movement
				move(delta)
			
			if is_in_group("ally"):
				if is_close_to_target(2):
					#print("Ally close to target")
					# face where the player is looking
					face_pos = player.get_global_transform().xform(Vector3(0, 0, 5))
			
			else:
				#paranoia
				if target_array.size() > 0 \
				and is_close_to_target() and not brain.get_state() == brain.STATE_ALARMED and not brain.get_state() == brain.STATE_DISENGAGE:
					# should look around for a while
					if get_node("Timer2").is_stopped():
						get_node("Timer2").start()
					
					##do we have a next point?
					if (target_array.size() > current+1):
						prev = current
						current = current + 1
					else:
						# assume all AI paths are loops for now
						current = 0

					# send to brain
					brain.target = target_array[current]
				
				# look around (sniper's version is elsewhere)
				if get_name() != "sniper" \
				and get_node("Timer2").time_left > 0 and not brain.get_state() == brain.STATE_ALARMED and not brain.get_state() == brain.STATE_DISENGAGE:
					#print("Timer's on, ", get_node("Timer2").time_left)
					var w = get_node("Timer2").time_left/2.0 # 2 is the total timer
					#print("lerp weight: ", w)
					var look_at = lerp(Vector2(-0.5, 0), Vector2(0.5, 0), w)
					#print("Look at: ", look_at.x)
					var rot = lerp(-45, 45, w)
					#var look_at = Vector2(0.5, 0) # 1 is 90 degrees
					state_machine["parameters/look/blend_position"] = look_at
					# adjust vision cone to match
					$RotationHelper/Area.rotation_degrees = Vector3(0,rot,0) # nullify any previous
					#$RotationHelper/Area.rotate_y(deg2rad(-45))
					
						
		
		if brain.get_state() == brain.STATE_ALARMED and !is_in_group("ally"):
			move(delta)
			
		else:
			if not brain.get_state() == brain.STATE_SEARCH:
				#white
				get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, think_emote)
	
	# debug
	if brain.target != null and is_instance_valid(brain.target):
		if typeof(brain.target) == TYPE_VECTOR3:
			get_node("MeshInstance2").set_translation(brain.target)
		else:
			get_node("MeshInstance2").set_translation(brain.target.get_global_transform().origin)
			
	if not possible_tg:
		in_sight = false
		# reset ally's alarmed flag
		if is_in_group("ally"):
			alarmed = false
		return
	#else:
	#	print("We have a possible tg!", possible_tg.get_global_transform().origin)
		
	if dead or unconscious:
		in_sight = false
		alarmed = false
		return
	
	# Can we see the player?
	# Get the raycast node
	var ray = $RotationHelper/Area/RayCast
	ray.collision_mask = 1
	ray.collide_with_areas = false
	
	# set the proper cast_to
	ray.cast_to = ray.to_local(possible_tg.get_global_transform().origin) #*1.5
	
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body_r = ray.get_collider()
		#print("Body_r", body_r)
		if body_r is KinematicBody:
			if body_r.is_in_group("player"):
				if possible_tg.get_parent() == body_r:
					# no need to do backdrop detection if player is prone
					if !possible_tg.get_parent().stance == 2:
						# assume only player is a possible_tg
						possible_tg.get_parent().backdrop = null
						# detect the backdrop
						var ray2 = $RotationHelper/Area/RayCast2
						ray2.cast_to = ray.to_local(possible_tg.get_global_transform().origin) *2
				
						# Force the raycast to update. This will force the raycast to detect collisions when we call it.
						# This means we are getting a frame perfect collision check with the 3D world.
						ray2.force_raycast_update()

						# Did the ray hit something?
						if ray2.is_colliding():
							var body_bg = ray2.get_collider()
							#print(body_bg)
							if body_bg is StaticBody or body_bg is CSGCombiner:
								#print("Backdrop is " + str(body_bg.get_parent().get_name()))
								possible_tg.get_parent().backdrop = body_bg.get_parent().get_name()
							#else:
							#	print("No backdrop detected, assuming floor")
						#else:
						#	print("No backdrop detected, assuming floor")
					#else:
					#	print("Player prone, no backdrop detection")
			
					# ----------------------------------
					# we can see the player because he's not hidden
					if !possible_tg.get_parent().is_hiding()[0]:
						# if we see an enemy, no longer need to turn to face a shot
						face_pos = Vector3()
						# stop the look around timer, too
						get_node("Timer2").stop()
						
						#get_node("time_to_look").start()
						if timetospot > 0:
							timetospot = timetospot- delta
							#print("Timetospot: ", timetospot)
						if timetospot <= 0:
							_on_player_seen(body_r)
					
					# hidden, can't see
					else:
						if not brain.get_state() in [brain.STATE_ALARMED, brain.STATE_SEARCH]:
							get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, cantsee_emote)
						in_sight = false
						# straighten out
						set_rotation(Vector3(0,get_rotation().y,0))
						# reset time to spot
						timetospot = 1.0
						
						# we lost sight of an enemy?
						if last_seen_pos != Vector3.ZERO and not brain.get_state() == brain.STATE_SEARCH:
							#get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, seen_emote)
							print("Lost sight of an enemy last seen @: ", last_seen_pos)
							brain.set_state(brain.STATE_SEARCH)
							emit_signal("emit_bark", self, "Seen something! Searching now...")
			
			# kinematic body detected that isn't player 
			else:
				# assume it is our possible_tg
				if body_r == possible_tg:
					# if we see an enemy, no longer need to turn to face a shot
					face_pos = Vector3()
					if has_node("Timer2"):
						# stop the look around timer, too
						get_node("Timer2").stop()
					
					if timetospot > 0:
						timetospot = timetospot - delta
						#print("Timetospot: ", timetospot)
					if timetospot <= 0:
						last_seen_pos = body_r.global_transform.origin
						# red
						get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, hostile_emote)
						
						# look at target
						look_at(body_r.global_transform.origin, Vector3(0,1,0))
						# because this looks the opposite way for some reason
						rotate_y(deg2rad(180))
						in_sight = true
						
						#AI_shoot(body_r)
						
						if not alarmed:
							emit_signal("enemy_seen")
							alarmed = true
			
		# no body detected means can't see the player
		else:
			if not brain.get_state() in [brain.STATE_ALARMED, brain.STATE_SEARCH]:
				# white
				get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, think_emote)
			in_sight = false
			# straighten out
			set_rotation(Vector3(0,get_rotation().y,0))
			# reset time to spot
			timetospot = 1.0
			# we lost sight of an enemy?
			if last_seen_pos != Vector3.ZERO and not brain.get_state() == brain.STATE_SEARCH:
				#get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, seen_emote)
				print("Lost sight of an enemy last seen @: ", last_seen_pos)
				brain.set_state(brain.STATE_SEARCH)
				emit_signal("emit_bark", self, "Seen something! Searching now...")

# enemy_seen is allied AI specific for now
func _on_player_seen(body_r):
	# note that we've seen an enemy
	last_seen_pos = body_r.global_transform.origin
	
	# if we see the player for the first time and alarm hasn't been raised (if any in level)
	if not in_sight and not get_name() == "sniper" \
	and get_tree().get_nodes_in_group("alarm").size() > 0 and !get_tree().get_nodes_in_group("alarm")[0].get_child(0).alarmed \
	and not alarmed:
		brain.set_state(brain.STATE_ALARMED)
		brain.target = get_tree().get_nodes_in_group("alarm")[0]
		print("ALARM!!!")
		# AI can only be alarmed by you once
		alarmed = true
		emit_signal("emit_bark", self, "Raising an alarm!")
		# yellow
		get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, alarmed_emote)
	else:
		if not brain.get_state() == brain.STATE_ALARMED:
			# red
			get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, hostile_emote)
		
			if get_name() == "sniper":
				print("Sniper spotted player")
				reset_head()
				
			# sniper doesn't need to rotate but everyone else does
			else:
				reset_head()
				
				# look at player
				look_at(body_r.global_transform.origin, Vector3(0,1,0))
				# because this looks the opposite way for some reason
				rotate_y(deg2rad(180))
				
				AI_shoot(body_r)
			
			in_sight = true
			if brain.get_state() == brain.STATE_SEARCH:
				brain.state.found = true # we found the enemy, no more searching
				emit_signal("emit_bark", self, "Found him!")
				# reset last seen
				last_seen_pos = Vector3()

# assumes we get passed a valid target
func AI_shoot(target):
	var shoot_loc = target.global_transform.origin
	var target_collision_h = 0.92 # hardcoded
	#print("Shoot target: ", target)
	var offset = Vector3(0,1,0)*((randf()*2-1)*target_collision_h)
	#print("offset: ", offset)
	shoot_loc = shoot_loc + offset
	# this is global
	#print("Shoot loc", shoot_loc)
	# this one actually fires
	AI_fire_weapon(shoot_loc)
	
	
# fire_weapon() in shoot.gd has a lot of player-centric stuff so here we go...
# hitscan weapon
func AI_fire_weapon(shoot_loc):
	# Get the raycast node
	var ray = $RotationHelper/Area/RayCast
	ray.collision_mask = 2
	ray.collide_with_areas = true
	
	# cast to our shoot loc
	ray.cast_to = ray.to_local(shoot_loc) #* 1.25
	
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		
		#debug
		if body == self or body.get_node("../../../../..") == self:
			print("Hit self!")
			
		#print("Body...", body.get_name())
		
		# body parts support (requires detecting areas!)
		if body is Area and body.get_parent() is BoneAttachment:
			#print(body.get_node("../../../../..").get_name())
			# player version
			if body.get_node("../../../../..").is_in_group("player"):
				var bone = body.get_parent().get_name()
				#print("Bone...", bone)
				
				body.get_node("../../../../..").body_part_damaged(body.get_node("../../../../..").bone_to_bp(bone))
				
			# AI version
			if body.get_node("../../../../..").is_in_group("AI"):
				var bone = body.get_parent().get_name()
				#print("Bone...", bone)
				if bone.find("Chest") != -1 or bone.find("Head") != -1 or bone.find("Neck") != -1:
					body.get_node("../../../../..").die(get_global_transform().origin)
				elif bone.find("Arm") != -1:
					body.get_node("../../../../..").drop_gun(self)
					body.get_node("../../../../..")._on_hurt(get_global_transform().origin)
				else:
					body.get_node("../../../../..")._on_hurt(get_global_transform().origin)


# ------------------------------------------------------------
func physical_bones_set_collision(boo):
	var layer = int(boo) # we only toggle 0 or 1
	for c in get_node("RotationHelper/Character2/Armature").get_children():
		if c is PhysicalBone:
			c.collision_layer = layer

func ragdoll(knock):
	var rot = deg2rad(-90)
	if knock > 0:
		rot = deg2rad(90)
	physical_bones_set_collision(true)
	get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation()
	get_node("RotationHelper/Character2").set_rotation(Vector3(rot, 0, 0))
	get_node("CollisionShape").disabled = true # only the ragdoll should be active

# the position passed here is global
func die(pos):
	var rel_loc = to_local(face_pos)
	#2D angle to target (local coords)
	var angle = atan2(rel_loc.x, rel_loc.z)
	print("Local position of hit: ", rel_loc, "angle: ", angle)
	
	var knock = deg2rad(-40)
	if rel_loc.z < 0:
		knock = deg2rad(40)
	
	if !get_name() == "sniper":
		# tip him back
		get_node("RotationHelper/Character2").set_rotation(Vector3(knock, 0, 0))
	# switch off animtree
	get_node("RotationHelper/Character2/AnimationTree").active = false
	# .. and IK
	$RotationHelper/Character2/Armature/rifleik.stop()
	$RotationHelper/Character2/Armature/left_ik.stop()
	
	# hide the state marker
	get_node("RotationHelper/MeshInstance").hide()
	
	#get_node("RotationHelper/Character2/Timer").start()
	
	# ragdoll
	ragdoll(knock)
	
	dead = true

func drop_gun(enemy):
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
	
	# withdraw
	brain.set_state(brain.STATE_DISENGAGE)
	brain.target = enemy

# the position passed here is global
func knock_out(pos):
	var rel_loc = to_local(face_pos)
	#2D angle to target (local coords)
	var angle = atan2(rel_loc.x, rel_loc.z)
	print("Local position of hit: ", rel_loc, "angle: ", angle)
	
	var knock = deg2rad(-40)
	if rel_loc.z < 0:
		knock = deg2rad(40)
	# tip him back
	get_node("RotationHelper/Character2").set_rotation(Vector3(knock, 0, 0))
	# switch off animtree
	get_node("RotationHelper/Character2/AnimationTree").active = false
	# .. and IK
	$RotationHelper/Character2/Armature/rifleik.stop()
	$RotationHelper/Character2/Armature/left_ik.stop()
	
	# ragdoll
	ragdoll(knock)

	unconscious = true
	get_node("wake_timer").start()

# the position passed here is global
func _on_hurt(pos):
	if dead:
		return
	
	face_pos = pos


func is_armed():
	if is_in_group("civilian"):
		return false
	
	var hold = get_node("RotationHelper/Character2/Armature/WeaponHold")
	# for now, AI can only have rifles
	return hold.has_node("Rifle2")


func reset_head():
	# reset back to defaults
	var look_y = 0
	var x = 0
	if get_name() == "sniper":
		look_y = 0.5
		x = rad2deg(0.5)
	var look_at = Vector2(0, look_y) # 1 is 90 degrees
	state_machine["parameters/look/blend_position"] = look_at
	
	# adjust vision cone to match
	$RotationHelper/Area.rotation_degrees = Vector3(x,0,0) # nullify any previous

# AI targeting
func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		possible_tg = body.get_node("see_tg")
		player.possibly_seen_by = self
		#print("Possible tg: ", body.get_node("see_tg").get_global_transform().origin)
	# detecting bodies
	elif body is PhysicalBone:
		var ch = body.get_node("../../../..") 
		if ch != self and ch.is_in_group("AI") and (ch.unconscious or ch.dead):
#	if body.is_in_group("AI"):
#		if body.unconscious or body.dead:
			print("I saw a body")
			alarmed = true
	elif body is RigidBody:
		if body.is_in_group("grenade"):
			print("I saw a grenade")
			grenade_threat = body

func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		# paranoia/bugfix (it's possible to trigger this while still being in_sight of a sniper)
#		if get_name() == "sniper" \
#		and get_global_transform().origin.distance_to(possible_tg.get_global_transform().origin) < 8:
#			return
		
		player.possibly_seen_by = null
		print("Player left the viewcone")
#		if get_name() == "sniper":
#			# debug
#			print("Dist to sniper: ", get_global_transform().origin.distance_to(possible_tg.get_global_transform().origin))
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, think_emote)
		
		if get_name() != "sniper":
			# straighten out
			set_rotation(Vector3(0,get_rotation().y,0))
		else:
			get_node("Timer2").start()
	if body is RigidBody:
		if body.is_in_group("grenade"):
			print("Grenade out of sight")
			grenade_threat = null


# ally versions
func _on_Area_body_entered2(body):
	if !body.is_in_group("ally") and !body.is_in_group("civilian") and body.is_in_group("AI"):
		possible_tg = body


func _on_Area_body_exited2(body):
	if !body.is_in_group("ally") and !body.is_in_group("civilian") and body.is_in_group("AI"):
		#print("Enemy left view")
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, think_emote)
		# straighten out
		set_rotation(Vector3(0,get_rotation().y,0))

# -------------------------------------------------------
func _on_Timer_timeout():
	# haven't seen anyone, go back to normal
	face_pos = Vector3()
	# sniper: special case - wait before starting to look around again
	if get_name() == "sniper" and not in_sight:
		get_node("Timer2").start()

func _on_Timer2_timeout():
	reset_head()
	
	# special case
	if get_name() == "sniper":
		if not in_sight:
			get_node("Timer").start()


# can't use a timer because we need a reference to the actual body_r
#func _on_time_to_look_timeout():
#	_on_player_seen(body_r)
#	pass # Replace with function body.

func _on_knockout_timer_timeout():
	# tranqs are silent and don't hurt much (just a pinch) so they can't tell the direction...
	knock_out(to_global(Vector3(0,0,-1)))

func _on_wake_timer_timeout():
	print("Woke up!!!")

	get_node("RotationHelper/Character2").set_rotation(Vector3(0, 0, 0))
	
	# no more ragdoll
	get_node("CollisionShape").disabled = false
	get_node("RotationHelper/Character2/Armature").physical_bones_stop_simulation()
	
	# reenable animtree
	get_node("RotationHelper/Character2/AnimationTree").active = true
	# .. and IK
	$RotationHelper/Character2/Armature/rifleik.start()
	$RotationHelper/Character2/Armature/left_ik.start()
	
	unconscious = false

func _on_enemy_seen():
	pass
	#print("Enemy seen!")	

# ---------------------------------------------------------
func _on_thermal_vision(on):
	# visual effect
	#var mesh = get_node("RotationHelper/Character2/Armature/Body")
	var index = 1
	if is_in_group("civilian"):
		#mesh = get_node("RotationHelper/model/Human Armature/Skeleton/Human_Mesh")
		index = 0
	if on:
		mesh.set_surface_material(index, thermal)
	else:
		mesh.set_surface_material(index, camo)

func optic_camo_effect():
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	mesh.set_surface_material(0, optic_camo)
	mesh.set_surface_material(1, optic_camo)

func _on_answer_selected(screen, id):
	print("On answer selected, id ", id)
	if is_in_group("boss"):
		if screen.current_tag == "start":
			screen.clear_answers()
			screen.set_answers(["Yes, sir!"])
			screen.show_line(screen.dialog.lines["mission"], "mission")
			return false
		else:
			return
		
	if is_in_group("civilian"):
		return
		
	if is_in_group("ally"):
		# wait a bit
		#yield(get_tree().create_timer(1), "timeout")
		# toggle the state
		if id == 2:
			# check prev state because talking sets us to idle temporarily
			if brain.prev_state == brain.STATE_FOLLOW:
				brain.set_state(brain.STATE_IDLE)
				print("Ally should idle")
			else:
				brain.set_state(brain.STATE_FOLLOW)
				print("Ally should follow")


