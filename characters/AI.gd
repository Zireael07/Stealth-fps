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
var player = null
var draw = null
var elapsed_sec = 0

# material
var camo = preload("res://assets/camo_triplanar_mat.tres")
var thermal = preload("res://assets/thermal_vis_material.tres")
var optic_camo = preload("res://assets/optic_camo_material.tres")

# allies
signal enemy_seen

# Called when the node enters the scene tree for the first time.
func _ready():
	# b/c it's placed in global space
	get_node("MeshInstance").set_as_toplevel(true)
	if is_in_group("ally"):
		get_node("MeshInstance2").set_as_toplevel(true)
	#get_node("RotationHelper/Character2/Timer").connect("timeout", self, "ragdoll")
	
	player = get_tree().get_nodes_in_group("player")[0]
	
	connect("enemy_seen", self, "_on_enemy_seen")
	connect("enemy_seen", player, "on_enemy_seen")
	
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	if is_in_group("civilian"):
		mesh = get_node("RotationHelper/model/Human Armature/Skeleton/Human_Mesh")
	
	state_machine = $RotationHelper/Character2/AnimationTree
	
	brain = $brain
	
	# get points
	if get_node(nav):
		for c in get_node(nav).get_children():
			target_array.append(c)
		#brain.target = get_parent().get_node("nav").get_child(0)
		brain.target = target_array[0]
	
	# debug helpers
	draw = player.get_node("Control/DebugDraw")
	if is_in_group("ally"):
		register_debugging_lines()
	
	
	# fake aabb for outlines
	var debug = $RotationHelper/Character2/Armature/HitBoxTorso/center
	var scale = Vector3(1,1,1)
	if is_in_group("civilian"):
		debug = $"RotationHelper/model/Position3D"
		scale = Vector3(0.35, 0.35, 0.35)
	
	for i in range(7):
		var end_point = mesh.get_aabb().get_endpoint(i) * scale # local space
		 # because we're looking at relative to center
		var point = to_global(end_point)
		var pt = Position3D.new()
		#var msh = CubeMesh.new()
		#msh.size = Vector3(0.25, 0.25, 0.25)
		#var pt = MeshInstance.new()
		#pt.set_mesh(msh)
		debug.add_child(pt)
		pt.global_transform.origin =  point


#- ----------------------------
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
		if !is_in_group("ally"):
			return
			
		# debugging
		if get_viewport().get_camera().get_name() == "TopDownCamera":
			draw.update_line(self, 0, get_global_transform().origin, brain.target)
			draw.update_line(self, 1, get_global_transform().origin, to_global(Vector3(brain.velocity.x, 0, brain.velocity.y)))
			draw.update_line(self, 2, get_global_transform().origin, to_global(Vector3(brain.steer.x, 0, brain.steer.y)))
			draw.update_line(self, 3, get_global_transform().origin, to_global(Vector3(brain.desired.x, 0, brain.desired.y)))
	#	pass

func dist_to_target():
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
	# state sets the steer/rotations used below
	brain.state.update(delta)
	#brain.steer = brain.arrive(brain.target, 5)
	
	# rotations if any
	#self.rotate_y(deg2rad(brain.steer.x * STEER_SENSITIVITY))  #* -1))
	
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
	if not carried and (dead or unconscious):
		# attempt to sync collision with ragdoll
		global_transform.origin = get_node("RotationHelper/Character2/Armature/HitBoxPelvis/Area/CollisionShape").global_transform.origin
		return
	
	if not dead and not unconscious:
		# animate movement
		if state_machine:
			if vel.length() > 0:
				state_machine["parameters/move_state/run/blend_position"] = Vector2(0,1) # actually animates leg movement
			else:
				state_machine["parameters/move_state/run/blend_position"] = Vector2(0,0) # stop moving
		
		if is_in_group("civilian"):
			brain.set_state(brain.STATE_IDLE)
			return
			
		if is_in_group("ally"):
			# stay "a step behind" the player
			brain.target = player.get_global_transform().xform(Vector3(0, 0, -3))
			# debug
			get_node("MeshInstance2").set_translation(brain.target)
			#brain.set_state(brain.STATE_IDLE)
			#return
		
		# if we're unarmed, disengage
		if !is_armed() and in_sight:
			brain.set_state(brain.STATE_DISENGAGE)
			brain.target = possible_tg
		
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
			
			if is_in_group("ally"):
				if is_close_to_target(2):
					#print("Ally close to target")
					# hack
					face_pos = player.get_global_transform().origin
			
			else:
				if is_close_to_target() and not alarmed and not brain.get_state() == brain.STATE_DISENGAGE:
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
			# yellow
			get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,0))
			
			brain.target = get_tree().get_nodes_in_group("alarm")[0]
			#print("Brain tg is alarm")
			
			move(delta)
			
			if is_close_to_target(1.5):
				print("Reached button")
				#interact with it
				get_tree().get_nodes_in_group("alarm")[0].get_child(0)._on_interact()
				alarmed = false
		else:
			#white
			get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))
		
	if not possible_tg:
		in_sight = false
		#alarmed = false
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
					if !possible_tg.get_parent().is_hiding():
						# if we see an enemy, no longer need to turn to face a shot
						face_pos = Vector3()
						
						# if we see the player for the first time and alarm hasn't been raised
						if not in_sight and not alarmed and !get_tree().get_nodes_in_group("alarm")[0].get_child(0).alarmed:
							#print("ALARM!!!")
							alarmed = true
							# yellow
							get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,0))
						else:
							# red
							get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,0,0))
						
						# look at player
						look_at(body_r.global_transform.origin, Vector3(0,1,0))
						# because this looks the opposite way for some reason
						rotate_y(deg2rad(180))
						in_sight = true
					
					# hidden, can't see
					else:
						if not alarmed:
							# cyan
							get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(0,1,1))
						in_sight = false
						# straighten out
						set_rotation(Vector3(0,get_rotation().y,0))
			
			# kinematic body detected that isn't player 
			else:
				# assume it is our possible_tg
				if body_r == possible_tg:
					# if we see an enemy, no longer need to turn to face a shot
					face_pos = Vector3()
					
					# red
					get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,0,0))
					
					
					# look at target
					look_at(body_r.global_transform.origin, Vector3(0,1,0))
					# because this looks the opposite way for some reason
					rotate_y(deg2rad(180))
					in_sight = true
					
					if not alarmed:
						emit_signal("enemy_seen")
						alarmed = true
			
		# no body detected means can't see the player
		else:
			if not alarmed:
				# white
				get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))
			in_sight = false
			# straighten out
			set_rotation(Vector3(0,get_rotation().y,0))

func ragdoll(knock):
	var rot = deg2rad(-90)
	if knock > 0:
		rot = deg2rad(90)
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
	# tip him back
	get_node("RotationHelper/Character2").set_rotation(Vector3(knock, 0, 0))
	# switch off animtree
	get_node("RotationHelper/Character2/AnimationTree").active = false
	# .. and IK
	$RotationHelper/Character2/Armature/rifleik.stop()
	$RotationHelper/Character2/Armature/left_ik.stop()
	
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


# AI targeting
func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		possible_tg = body.get_node("see_tg")
		#print("Possible tg: ", body.get_node("see_tg").get_global_transform().origin)
	# detecting bodies
	elif body is PhysicalBone:
		var ch = body.get_node("../../../..") 
		if ch != self and ch.is_in_group("AI") and (ch.unconscious or ch.dead):
#	if body.is_in_group("AI"):
#		if body.unconscious or body.dead:
			print("I saw a body")
			alarmed = true


func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		print("Player left the viewcone")
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))
		# straighten out
		set_rotation(Vector3(0,get_rotation().y,0))

# ally versions
func _on_Area_body_entered2(body):
	if !body.is_in_group("ally") and !body.is_in_group("civilian") and body.is_in_group("AI"):
		possible_tg = body
		
	pass # Replace with function body.

func _on_Area_body_exited2(body):
	if !body.is_in_group("ally") and !body.is_in_group("civilian") and body.is_in_group("AI"):
		#print("Enemy left view")
		possible_tg = null
		get_node("RotationHelper/MeshInstance").get_material_override().set_albedo(Color(1,1,1))
		# straighten out
		set_rotation(Vector3(0,get_rotation().y,0))

# -------------------------------------------------------
func _on_Timer_timeout():
	# haven't seen anyone, go back to normal
	face_pos = Vector3()

func _on_thermal_vision(on):
	# visual effect
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	var index = 1
	if is_in_group("civilian"):
		mesh = get_node("RotationHelper/model/Human Armature/Skeleton/Human_Mesh")
		index = 0
	if on:
		mesh.set_surface_material(index, thermal)
	else:
		mesh.set_surface_material(index, camo)


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
	print("Enemy seen!")

func optic_camo_effect():
	var mesh = get_node("RotationHelper/Character2/Armature/Body")
	mesh.set_surface_material(0, optic_camo)
	mesh.set_surface_material(1, optic_camo)
