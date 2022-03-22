extends KinematicBody

var player = true

const GRAVITY = -24.8
var vel = Vector3()
var MAX_SPEED = 20 # depends on stance
var ACCEL = 1 #4.5
const JUMP_SPEED = 10 #18
const SWIM_SPEED = 5

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
var grabbed_previous_layers = null # because some items might be on more than one layer
const OBJECT_THROW_FORCE = 5
const VIS_OBJECT_GRAB_DISTANCE = 1
#const OBJECT_GRAB_RAY_DISTANCE = 10

var binocs = false
var scoping = false
var wpn_spread = 1.2
var cur_spread = 0

# states (weapons)
const UNARMED = 0
const RIFLE = 1
const BATON = 2
const KNIFE = 3
const XBOW = 4
var state = RIFLE
var prev_state = RIFLE

var inventory = {}

# material
var default = preload("res://assets/blue_principled_bsdf.tres")
var camo = preload("res://assets/camo_triplanar_mat.tres")

# hiding
const DEFAULT = 0
const CAMO = 1
var uniform = DEFAULT

var backdrop = null

var shadow_ray = null
var shadow_ray_tg = null

# long actions
var action = null

var talking = false

var swimming = false
var climbing = false

func _ready():
	camera = $RotationHelper/Character/Armature/CameraBoneAttachment/Camera
	weapon_hold = $RotationHelper/Character/Armature/WeaponHold/
	camera_helper = $RotationHelper/Character/Armature/HitBoxChest/Spatial # for ik targets
	rotation_helper = $RotationHelper
	
	left_ik_tg = camera_helper.get_node("left_ik_tg")
	
	state_machine = $RotationHelper/Character/AnimationTree
	
	shadow_ray = $see_tg/ShadowRayCast
	
	# mission setup
	get_node("Control/troop selection").show()
	get_tree().set_pause(true)
	get_node("Control/scoring").hide()

func game_start(data):
	# FPS input
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# enable IK
	$RotationHelper/Character/Armature/left_ik.start()
	$RotationHelper/Character/Armature/rifleik.start()
	$RotationHelper/Character/Armature/headik.start()
	
	if get_tree().get_nodes_in_group("root")[0].has_node("shadow_ray_tg"):
		# make the shadow ray rotation match the sun rotation
		shadow_ray.rotation.x = get_tree().get_nodes_in_group("root")[0].get_node("DirectionalLight").rotation.x
		# set the shadow ray tg
		shadow_ray_tg = get_tree().get_nodes_in_group("root")[0].get_node("shadow_ray_tg")
		# place the tg at a correct spot
		# since tangent is opposite/adjacent, opposite is tan*adjacent
		var y = tan(shadow_ray.rotation.x)*200
		shadow_ray_tg.translate(Vector3(0,-y,0))

	# tutorial level has no allies
	if get_tree().get_nodes_in_group("ally").size() > 0:
		# set correct ally name
		get_tree().get_nodes_in_group("ally")[0].set_name(data[0])
		get_node("Control/bottom_panel/AllyPanel/ColorRect/Label").set_text(data[0])
		
		get_node("Control/scoring/ToBeat").set_text("To Beat: " + data[0] + " 80/100")

		# if we picked Ana, she comes with an optic camo
		if data[0] == "Ana Navarro":
			get_tree().get_nodes_in_group("ally")[0].optic_camo_effect()

func is_gun():
	return state == RIFLE or state == XBOW


# these things don't need physics
func _process(delta):
	if Input.is_action_just_pressed("menu"):
		if !get_node("Control/inventory").visible:
			get_node("Control/inventory").show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			get_node("Control/inventory").hide()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_pressed("map"):
		if !get_node("Control/map_screen").visible:
			get_node("Control/map_screen").show()
		else:
			get_node("Control/map_screen").hide()
	if Input.is_action_just_pressed("topdown"):
		var top_down = get_tree().get_nodes_in_group("root")[0].get_node("TopDownCamera")
		top_down.set_current(!top_down.is_current())
		if !top_down.is_current():
			camera.set_current(true)


func _physics_process(delta):
	# adjust current spread
	# do first so that taking long actions also lowers your spread
	if !is_moving():
		cur_spread = clamp(cur_spread-0.1, 0, wpn_spread)
	elif !is_gun():
		cur_spread = 0
		wpn_spread = 0 
	else:
		cur_spread = wpn_spread
	
	# prevent doing things manually while doing long actions
	if action != null or talking:
		return
		
	process_input(delta)
	process_movement(delta)
	camera.get_node("Spatial").iff()
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
	
	if stance != PRONE:
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
		weapon_hold.get_node("Crossbow").hide()
	elif state == BATON:
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").show()
		weapon_hold.get_node("Knife").hide()
		weapon_hold.get_node("Crossbow").hide()
		if stance != PRONE:
			left_hand_empty_ik()
	elif state == KNIFE:
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Knife").show()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Crossbow").hide()
		if stance != PRONE:
			left_hand_empty_ik()
	elif state == XBOW:
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Knife").hide()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Crossbow").show()
		if stance != PRONE:
			left_hand_empty_ik()	
	
	if stance != PRONE:
		# restore the previous right hand IK
		# these are the initial values upon game start
		camera_helper.get_node("rifle_ik_tg").set_translation(Vector3(0.65, 2.2, 1.75))
		camera_helper.get_node("rifle_ik_tg").rotation_degrees = Vector3(0, 0, 0)
		#$RotationHelper/Character/Armature/rifleik.start()
	
	
	# update HUD
	get_node("Control/Center/Crosshair").show()
	get_node("Control/Center/Control").hide()

# this is run every tick when we have a grabbed object
# avoids the need to reparent the object
func place_grabbed_object(grabbed_object):
	var rotation = global_transform.basis.get_euler()
	
	var x_offset = camera.global_transform.basis.y.normalized() * -0.5
	
	if grabbed_object is KinematicBody:
		# this represents pulling by the chest at our chest level (think DX1)
		x_offset = Vector3(0,-1.5,0) # experimentally determined
	
	var z_offset = (-camera.global_transform.basis.z.normalized() * VIS_OBJECT_GRAB_DISTANCE)
	
	grabbed_object.global_transform.origin = camera.global_transform.origin + z_offset + x_offset
	grabbed_object.rotation = rotation

func add_to_inventory(item):
	# interactable cleanup
	camera.get_node("Spatial").last_interactable = null
	get_node("Control/ReferenceRect").hide()
	
	# remove from world (pick up)
	#inter.queue_free()
	item.add_to_group("inventory")
	# show in inventory menu
	get_node("Control/inventory").update_slot(item)
	get_node("Control/inventory").update_others(item)
	get_node("Control/inventory").select_item(item)
	
	# assumes all pickable items are RigidBodies
	item.mode = RigidBody.MODE_STATIC

	item.collision_layer = 0
	item.collision_mask = 0
	
	item.hide()
	
func drop_item(item):
	item.remove_from_group("inventory")
	
	# hack
	place_grabbed_object(item)
	
	inventory[item.slot] = null
	item.slot = null
	
	item.mode = RigidBody.MODE_RIGID
	# make it collide again
	item.collision_layer = 1
	item.collision_mask = 1
	
	item.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE/4)
	item.show()
	
	
	# close inventory screen
	get_node("Control/inventory").hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
		# can't shoot while using binocs
		if binocs:
			return
			
		if state == UNARMED:
			wield_again()
			return
		
		if state == BATON:
			camera.get_node("Spatial").melee_weapon(true)
		elif state == KNIFE:
			camera.get_node("Spatial").melee_weapon(false)
		elif state == XBOW:
			wpn_spread = 1.5
			camera.get_node("Spatial").fire_darts()
		else:
			camera.get_node("Spatial").fire_weapon()
		
	if Input.is_action_just_pressed("shoot_alt"):
		# right click cancels binocs
		if binocs:
			# disable binocs zoom
			weapon_hold.get_node("binocs/BinocsCamera").set_current(false)
			weapon_hold.get_node("binocs/BinocsCamera/MeshInstance").hide()
			binocs = false
			camera.current = true
			return
		
		if not state == RIFLE:
			return
			
		if not scoping and not binocs:
			scoping = true
			$RotationHelper/Character/Armature/WeaponHold/Rifle2/Sight/AimCamera.current = true
		else:
			camera.current = true
			scoping = false

	# -------------------------------------------------------
	# Change stance (prone/crouch.standing)
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
			$see_tg.set_translation(Vector3(0, 0.527, 0.324))
			$CollisionShape.get_shape().extents = Vector3(0.249, 0.52, 0.757)
			#$"CollisionShapeGun".disabled = false
			# change anim
			state_machine["parameters/move_state/playback"].start("crouch")
		elif stance == STANDING:
#			var coll= move_and_collide(Vector3(0.5,0.1,0), false, true, true)
#			print("standing, coll: ", coll)
#			if coll:
#				stance = PRONE # don't change stance
#				return
			
			MAX_SPEED = 20
			ACCEL = 1
			$RotationHelper/Character/Armature/rifleik2.stop()
			$RotationHelper/Character/Armature/left_ik2.stop()
			# restore original values that prone changes
			$RotationHelper/Character.set_rotation_degrees(Vector3(0, 0, 0))
			$RotationHelper/Character.set_translation(Vector3(0, 0, 0))
			$CollisionShape.set_rotation_degrees(Vector3(0,0,0))
			$see_tg.set_translation(Vector3(0,0.927, 0.15))
			$"CollisionShapeGun".set_translation(Vector3(-0.205, 1.525, 0.694))
			#$"CollisionShapeGun".disabled = false
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
			# FIXME: stop things if we detect big y velocity (Shouldn't happen!)
			
#			var tr = $CollisionShape.transform.rotated(Vector3(1,0,0), 90)
#			tr.translated(Vector3(1,0,0))
#			#test_move(tr, Vector3(Vector3(0,0,-1)
#			print("Test move: ")
#			var coll= move_and_collide(Vector3(1,0.1,0), false, true, true)
#			var coll2= move_and_collide(Vector3(-1,0.1,0), false, true, true)
#			print("prone, coll: ", coll, "coll2", coll2)
			
			# check for collisions before going prone
			# check three rays to be sure we don't miss anything
			if $StanceRayCast.is_colliding() or $StanceRayCast2.is_colliding() or $StanceRayCast3.is_colliding():
				print("Colliding")
				stance -= 1 # don't change stance
				return
			
			MAX_SPEED = 10
			ACCEL = 0.25
			
			# the changes mean we're roughly 0.7 units tall (Z value)
			$RotationHelper/Character.set_rotation_degrees(Vector3(90, 0, 0))
			$RotationHelper/Character.set_translation(Vector3(1, 0, -1))
			$CollisionShape.set_rotation_degrees(Vector3(90,0,0))
			$CollisionShape.set_translation(Vector3(1, 0, 0))
			$see_tg.set_translation(Vector3(1, 0, 0))
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
			
			$"CollisionShapeGun".set_translation(Vector3(-0.205, 0, 0.95))
			# disable gun collision
			#$"CollisionShapeGun".disabled = true

	# --------------------------------------
	# weapon switching
	# main gun
	if Input.is_action_just_pressed("weapon_1"):
		state = RIFLE
		weapon_hold.get_node("Rifle2").show()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Knife").hide()
		weapon_hold.get_node("Crossbow").hide()
	# secondary gun
	if Input.is_action_just_pressed("weapon_2"):
		state = XBOW
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Knife").hide()
		weapon_hold.get_node("Crossbow").show()
		left_hand_empty_ik()
	# melee wp on belt
	if Input.is_action_just_pressed("weapon_3"):
		state = KNIFE
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").hide()
		weapon_hold.get_node("Knife").show()
		weapon_hold.get_node("Crossbow").hide()
		left_hand_empty_ik()
	# 4-9 other assorted stuff
	if Input.is_action_just_pressed("weapon_4"):
		state = BATON
		weapon_hold.get_node("Rifle2").hide()
		weapon_hold.get_node("Baton").show()
		weapon_hold.get_node("Knife").hide()
		weapon_hold.get_node("Crossbow").hide()
		left_hand_empty_ik()
	if Input.is_action_just_pressed("weapon_5"):
		print("Trying to access inventory slot grenade 1..")
		if inventory.has("GRENADE") and inventory["GRENADE"] != null:
			#inventory["GRENADE"].remove_from_group("inventory")
			# unwield any weapons
			unwield()
			# hack
			grabbed_object = inventory["GRENADE"]
			place_grabbed_object(grabbed_object)
			grabbed_object.show()
	if Input.is_action_just_pressed("weapon_6"):
		print("Trying to access inventory slot grenade 2..")
		if inventory.has("GRENADE2") and inventory["GRENADE2"] != null:
			#inventory["GRENADE2"].remove_from_group("inventory")
			# unwield any weapons
			unwield()
			# hack
			grabbed_object = inventory["GRENADE2"]
			place_grabbed_object(grabbed_object)
			grabbed_object.show()
	if Input.is_action_just_pressed("weapon_7"):
		if inventory.has("UTILITY") and inventory["UTILITY"] != null:
			if inventory["UTILITY"].get_name() != "binocs":
				print("Have lockpick in inventory")
				# unwield any weapons
				unwield()
				# hack
				grabbed_object = inventory["UTILITY"]
				place_grabbed_object(grabbed_object)
				grabbed_object.show()

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
			
			# if it's an NPC, try to interact
			if inter.is_in_group("civilian"):
				# unwield guns
				if state != UNARMED:
					unwield()
				
				var d = inter.get_node("dialogue")
				if d:
					# hide HUD
					get_node("Control/ReferenceRect").hide()
					get_node("Control/Center/Control").hide()
					
					# allow moving mouse
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					# prevent some other things
					talking = true
					# show conversation
					var conv = preload("res://hud/conversation.tscn")
					var c = conv.instance()
					get_node("Control").add_child(c)
					c.set_answers(d.answers)
					c.show_line(d.line)
					c.set_talker(inter)
					if inter.is_in_group("boss"):
						c.show_line("Welcome to the Coalition, Agent!")
						c.set_answers(["Thank you, sir!", "What is my task?"])
					
				else:
					print("You try to talk to ", inter.get_name(), " but he has nothing to say")
				return
				
			# if an ally, talk to him to give orders
			if inter.is_in_group("ally"):
				# unwield guns because we don't want to accidentally shoot the ally
				if state != UNARMED:
					unwield()
					
				var line = ""
				if inter.get_name() == "Herman Gunther":
					line = "Yes?"
				else:
					line = "Agent?"
				
				# hide HUD
				get_node("Control/ReferenceRect").hide()
				get_node("Control/Center/Control").hide()
				
				# allow moving mouse
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				# prevent some other things
				talking = true
				# show conversation
				var conv = preload("res://hud/conversation.tscn")
				var c = conv.instance()
				get_node("Control").add_child(c)
				c.show_line(line)
				var answers = ["Nothing"]
				if inter.brain.get_state() == inter.brain.STATE_FOLLOW:
					answers.append("Stay here!")
				else:
					answers.append("After me!")
				c.set_answers(answers)
				c.set_talker(inter)
				return
				
			
			# if it's a static object, run its function instead
			if inter.is_in_group("static"):
				inter._on_interact()
				return 
			
			# put items in inventory
			if inter.is_in_group("grenade"):
				# put in first grenade slot if empty
				if !inventory.has("GRENADE") or inventory["GRENADE"] == null:
					inventory["GRENADE"] = inter
					inter.slot = "GRENADE"
					print("Put " + inter.get_name() + " in grenade slot")
					add_to_inventory(inter)
					return
				# ... or in 2nd if not and 2nd is empty
				elif inventory.has("GRENADE") and (!inventory.has("GRENADE2") or inventory["GRENADE2"] == null):
					inventory["GRENADE2"] = inter
					inter.slot = "GRENADE2"
					add_to_inventory(inter)
					return
				# TODO: feedback for both slots taken
				else:
					return
			elif inter.is_in_group("pickup"):
				#if inter.get_name() == "binocs":
				if !inventory.has("UTILITY"):
					inventory["UTILITY"] = inter
					inter.slot = "UTILITY"
					print("Put " + inter.get_name() + " in utility")
					add_to_inventory(inter)
					if inter.has_method("_on_add_to_inventory"):
						inter._on_add_to_inventory(self)
				else:
					# TODO feedback for slot taken
					return
					
			grabbed_object = inter
			# clear interactable
			#camera.get_node("Spatial").last_interactable = null
			
			# unwield any weapons
			unwield()
			
			# grab it
			if grabbed_object is RigidBody:
				grabbed_object.mode = RigidBody.MODE_STATIC
			
			grabbed_previous_layers = grabbed_object.collision_layer

			grabbed_object.collision_layer = 0
			grabbed_object.collision_mask = 0
			
			if grabbed_object is KinematicBody:
				grabbed_object.carried = true
				#stop the ragdoll
				grabbed_object.get_node("RotationHelper/Character2/Armature").physical_bones_stop_simulation()
				grabbed_object.get_node("RotationHelper/Character2").set_rotation(Vector3(deg2rad(0), 0, 0))
				# test partial ragdoll
				grabbed_object.get_node("RotationHelper/Character2/Armature").physical_bones_start_simulation(["Head", "Chest", "Torso", "UpperLeg.R", "UpperLeg.L", "LowerLeg.R", "LowerLeg.L"])

		else:
			# are we aiming at another interactable?
			if camera.get_node("Spatial").last_interactable and is_instance_valid(camera.get_node("Spatial").last_interactable):
				#print("Aiming at interactable...")
				
				# can we interact with that interactable?
				if camera.get_node("Spatial").last_interactable.is_in_group("static"):
					# interact instead
					camera.get_node("Spatial").last_interactable._on_interact()
					return
				
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
					
					if grabbed_object.is_in_group("inventory"):
						# remove from inventory
						grabbed_object.remove_from_group("inventory")
						inventory[grabbed_object.slot] = null
						grabbed_object.slot = null
					
					
					# if it's a grenade, arm it
					if grabbed_object.is_in_group("grenade"):
						# remove from inventory
						grabbed_object.remove_from_group("inventory")
						inventory[grabbed_object.slot] = null
						grabbed_object.slot = null
						
						grabbed_object.armed = true
						grabbed_object.armed_flash()
						# reenable stickiness
						grabbed_object.get_node("StickyArea/CollisionShape2").disabled = false
						
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
			grabbed_object.collision_layer = grabbed_previous_layers if grabbed_previous_layers != null else 1
			grabbed_object.collision_mask = 1

			grabbed_object = null

	if grabbed_object != null:
		place_grabbed_object(grabbed_object)
	
	# ----------------------------------
	# Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel") and not talking:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# ----------------------------------

# Process our movements (influenced by our input) and sending them to KinematicBody
func process_movement(delta):
	if not swimming and not climbing:
		# Assure our movement direction on the Y axis is zero, and then normalize it.
		dir.y = 0
	else:
		if swimming:
			vel.y += delta * dir.y * SWIM_SPEED
		elif climbing:
			vel.y += delta * dir.y * 5
	dir = dir.normalized()
	if not swimming and not climbing:
		# Apply gravity
		vel.y += delta * GRAVITY
	else:
		vel.y += delta * GRAVITY/30 # buoyancy
	
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
	
	# FIX: if very big y and prone, bugs happen
	if vel.y < -30:
		print("Bug!")
		vel.y = 0
	
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

# ----------------------------------------------
func get_compass_heading():
	# because E and W were easiest to identify (the sun)
	# this relies on angle to marker
	var ang_to_dir = {180: "S", -180: "S", 0: "N", 90: "W", -90: "E"}

	# -180 -90 0 90 180 are the possible angles
	var num_to_dir = {0:"S", 1: "SE", 2:"E", 3: "NE", 4:"N", 5: "NW", 6:"W", 7: "SW", 8:"S"}
	# map from -180-180 to 0-4
	var rot = rad2deg(get_heading())
	var num_mapping = range_lerp(rot, -180, 180, 0, 8)
	var disp = num_to_dir[int(round(num_mapping))]
	
	return disp

func get_heading():
	var forward_global = get_global_transform().xform(Vector3(0, 0, -2))
	var forward_vec = forward_global-get_global_transform().origin

	if !has_node("/root/Spatial/marker_North"):
		return 0
	
	var North = get_node("/root/Spatial/marker_North")

	var rel_loc = get_global_transform().xform_inv(North.get_global_transform().origin)
	#2D angle to target (local coords)
	var angle = atan2(rel_loc.x, rel_loc.z)
	#print("Heading: ", rad2deg(angle))
	return angle

# ----------------------------------------------
func is_hiding():
	var hidden = false
	
	# if no backdrop, assume the floor (concrete)
	# same if we're lying down
	if not backdrop or stance == PRONE:
		if uniform == CAMO:
			hidden = true
	else:
		if backdrop != "Spatial":
			if uniform == DEFAULT:
				hidden = true
		else:
			if uniform == CAMO:
				hidden = true
	#print("Hidden: ", hidden)
	
	# check shadows
	if shadow_ray_tg == null:
		return hidden
		
	shadow_ray.cast_to = shadow_ray.to_local(shadow_ray_tg.get_global_transform().origin)
	
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	shadow_ray.force_raycast_update()
	# Did the ray hit something?
	if shadow_ray.is_colliding():
		var body_r = shadow_ray.get_collider()
		#print("Body_r", body_r)
		if body_r is StaticBody or body_r is CSGCombiner:
			print("We're in shadow")
			hidden = true
	
	return hidden

func is_moving():
	var move = vel.length() > 0.5 and stance != PRONE
	return move

func _on_convo_end(npc):
	# wait a bit
	yield(get_tree().create_timer(1), "timeout")
	if npc.is_in_group("ally"):
		wield_again()

# ---------------------------------------------
# this is mostly UI stuff
func show_binocs_menu():
	get_node("Control/UtilityItems").show()
	
func _on_gadget_mode(index):
	# visual: show binocs in hand
	weapon_hold.get_node("binocs/binocs_hand").show()
	weapon_hold.get_node("Rifle2").hide()
	weapon_hold.get_node("Baton").hide()
	weapon_hold.get_node("Knife").hide()
	weapon_hold.get_node("Crossbow").hide()
	#left_hand_empty_ik()
	
	if index < 3:
		for c in get_tree().get_nodes_in_group("AI"):
			c._on_thermal_vision(false)
	if index < 4:
		for o in get_tree().get_nodes_in_group("x-ray"):
			o.get_node("MeshInstance").set_material_override(null)
			# for bordered setup o needs to be the parent Glowing node
			#o.glow_border_effect = false
			#o.get_node("MeshInstance").get_surface_material(0).set_feature(SpatialMaterial.FEATURE_TRANSPARENT, false)
	
	if index == 0:
		get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment.adjustment_enabled = false
		# disable binocs zoom
		weapon_hold.get_node("binocs/BinocsCamera").set_current(false)
		weapon_hold.get_node("binocs/BinocsCamera/MeshInstance").hide()
		camera.set_current(true)
		binocs = false
	elif index == 1:
		weapon_hold.get_node("binocs/BinocsCamera").set_current(true)
		weapon_hold.get_node("binocs/BinocsCamera/MeshInstance").show()
		binocs = true
	elif index == 2:
		# turn nightvision on
		get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment.adjustment_enabled = true
	elif index == 3:
		get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment.adjustment_enabled = false
		# thermal effect
		for c in get_tree().get_nodes_in_group("AI"):
			c._on_thermal_vision(true)
	elif index == 4:
		for o in get_tree().get_nodes_in_group("x-ray"):
			o.set_material_override(preload("res://assets/xray_material2.tres"))
			# for bordered setup, o needs to be the parent GlowingObject
			#o.glow_border_effect = true
			#o.get_node("MeshInstance").get_surface_material(0).set_feature(SpatialMaterial.FEATURE_TRANSPARENT, true)
			
	# wait a bit
	yield(get_tree().create_timer(1), "timeout")
	# put binocs away
	weapon_hold.get_node("binocs/binocs_hand").hide()
	# show the current weapon again
	if state == RIFLE:
		weapon_hold.get_node("Rifle2").show()
	if state == BATON:
		weapon_hold.get_node("Baton").show()
	if state == KNIFE:
		weapon_hold.get_node("Knife").show()
	if state == XBOW:
		weapon_hold.get_node("Crossbow").show()
			
func _on_uniform_change(index):
	# close inventory screen
	get_node("Control/inventory").hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# queue up a long action
	long_action("Dressing", 5, index)

func uniform_change(index):
	var msh = $RotationHelper/Character/Armature/Body
	if index == 0:
		msh.set_surface_material(1, default)
		uniform = DEFAULT
	elif index == 1:
		msh.set_surface_material(1, camo)
		uniform = CAMO

func long_action(kind, time, data=null, tg=null):
	action = [kind, data, tg]
	# actually run stuff
	get_node("ActionTimer").start(time)
	get_node("Control/Center/ActionProgress").show()
	get_node("Control/Center/ActionProgress/VBoxContainer/Label").text = kind + "..."

func _on_action_finished(act):
	print("Action finished: ", act)
	if act[0] == "Dressing":
		uniform_change(act[1])
	if act[0] == "Opening":
		act[2].locked = false

func _on_ActionTimer_timeout():
	get_node("Control/Center/ActionProgress").hide()
	_on_action_finished(action)
	action = null

func on_enemy_seen():
	get_node("Control/bottom_panel/AllyPanel/ColorRect/radio_indicator").show()
	get_node("Control/bottom_panel/CommsLabel").show()
	get_node("Control/bottom_panel/CommsLabel").set_text("Enemy spotted!")
	
	yield(get_tree().create_timer(2), "timeout")
	get_node("Control/bottom_panel/AllyPanel/ColorRect/radio_indicator").hide()
	get_node("Control/bottom_panel/CommsLabel").hide()
	
	# this causes weird flickering of the Alert label
	#if not get_node("Control/AnimationPlayer2").is_playing(): 
	#	get_node("Control/AnimationPlayer2").play("New Anim")

func _on_emit_bark(who, msg):
	#print("Bark emitted: ", msg)
	get_node("Control/bottom_panel/AIBarksPanel").show()
	get_node("Control/bottom_panel/AIBarksPanel/Label").set_text(msg)
	
	yield(get_tree().create_timer(2), "timeout")
	get_node("Control/bottom_panel/AIBarksPanel").hide()
