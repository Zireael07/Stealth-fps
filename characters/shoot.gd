extends Spatial


# Declare member variables here. Examples:
var world_node = null
var bullet_impact = null

# because interactables use raycasts, they are in this script
var player = null
var last_interactable = null

# Called when the node enters the scene tree for the first time.
func _ready():
	world_node = get_tree().get_nodes_in_group("root")[0]
	bullet_impact = preload("res://bullet_impact.tscn")
	# player is so far up our tree that it's easier to go by group
	player = get_tree().get_nodes_in_group("player")[0]

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func create_bulletimpact(pos, normal, keep = false, bullet_hole = true):
	
	# Instance scene
	var instance = bullet_impact.instance();
	if (instance.has_method("bullet_hole")):
		instance.bullet_hole(bullet_hole);
	instance.keep = keep;
	world_node.add_child(instance);
	
	# Set transform
	instance.look_at_from_position(pos + (normal.normalized() * 0.01), pos + normal + Vector3(1, 1, 1) * 0.001, Vector3(0, 1, 0));


# so-called 'hitscan' weapon
func fire_weapon():
	# Get the raycast node
	var ray = $RayCast
	ray.collision_mask = 2
	if player.scoping:
		# offset due to weapon model not being exactly centered
		ray.cast_to = Vector3(3,-1,-50)
	else:
		# introduce spread
		var x = 0
		var y = 0
		if player.is_moving():
			x = rand_range(-1.0, 1.0) * player.cur_spread
			y = rand_range(-1.0, 1.0) * player.cur_spread
		ray.cast_to = Vector3(x,y,-50) # range of 50 m
		#print("Ray: ", Vector3(x,y, -50))
		$DebugAimPoint.set_translation(Vector3(x,y, -20))
		
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		#print("Body...", body.get_name())
		
		# body parts support (requires detecting areas!)
		if body is Area and body.get_parent() is BoneAttachment:
			var bone = body.get_parent().get_name()
			print("Bone...", bone)
			if bone.find("Chest") != -1 or bone.find("Head") != -1 or bone.find("Neck") != -1:
				body.get_node("../../../../..").die(get_global_transform().origin)
				#print(body.get_node("../../../../..").get_name()) #die()
			elif bone.find("Arm") != -1:
				body.get_node("../../../../..").drop_gun(player)
				body.get_node("../../../../..")._on_hurt(get_global_transform().origin)
			else:
				body.get_node("../../../../..")._on_hurt(get_global_transform().origin)
		
		if body is StaticBody:
			#print("hit: ", body.get_parent().get_name().find("target"))
			create_bulletimpact(ray.get_collision_point(), ray.get_collision_normal(), 
			body.get_parent().get_name().find("target") != -1, true)
			
			# we're a shooting target, do some math magic to figure out the scoring
			if body.get_parent().get_name().find("target") != -1:
				var point = body.get_parent().to_local(ray.get_collision_point())
				var dist = Vector2().distance_to(Vector2(point.x, point.y))
				#print("Hit dist is ", dist)
				# max dist is 0.5 (the diameter of the target is 1)
				# what fraction of max_dist are we away from the edge?
				var dist_to_edge = lerp(0.5, 0, dist/0.5)
				#print("Base", base_score)
				var score = lerp(1, 10, dist_to_edge*2) # dist_to_edge runs from 0.5
				#print("Score is ", round(score)) # 10 rings on a target
				# count off shots
				body.get_parent().get_parent().num_shots += 1
				# score display
				body.get_parent().get_parent().add_shot(score)
		if body is KinematicBody:
			body.die()
		if body is RigidBody:
			if body.is_in_group("explosive"):
				body.explode()

# so-called 'hitscan' weapon
# wasn't hitscan in DX, but instead used projectile physics (gravity pulling down)
func fire_darts():
	# Get the raycast node
	var ray = $RayCast
	ray.collision_mask = 2
	if player.scoping:
		ray.cast_to = Vector3(3,-1,-50)
	else:
		ray.cast_to = Vector3(0,0,-50) # range of 50 m
		
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		#print("Body...", body.get_name())
		
		# body parts support (requires detecting areas!)
		if body is Area and body.get_parent() is BoneAttachment:
			var bone = body.get_parent().get_name()
			print("Bone...", bone)
			body.get_node("../../../../..").get_node("knockout_timer").start()
			body.get_node("../../../../..").drop_gun(player)
			

func melee_weapon(knockout):
	# copied from interacting below
	# Get the raycast node
	var ray = $RayCast
	# interactable range is 4 m (to be slightly more generous, 2m range is more realistic but the majority of it is obscured by our arms/weapon)
	ray.cast_to = Vector3(0,0,-4) 
	ray.collision_mask = 2
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		#print("Colliding with: ", body.get_name())
		# body parts support (requires detecting areas!)
		if body is Area and body.get_parent() is BoneAttachment:
			var bone = body.get_parent().get_name()
			print("Bone...", bone)
			if knockout:
				# from player experience in DX, only neck/head and pelvis work
				if bone.find("Pelvis") != -1 or bone.find("Head") != -1 or bone.find("Neck") != -1:
					body.get_node("../../../../..").knock_out(get_global_transform().origin)
			else:
				if bone.find("Head") != -1 or bone.find("Chest") != -1 or bone.find("Neck") != -1:
					body.get_node("../../../../..").die(get_global_transform().origin)
				elif bone.find("Arm") != -1:
					body.get_node("../../../../..").drop_gun(player)
		if body is RigidBody:
			if body.is_in_group("explosive"):
				body.explode()

# --------------------------------------------------
# interactables use raycasting, so this code is also here
# TODO: move this out since this is player-specific
func draw_screen_outline(mesh, target):
	# bail early if in conversation mode
	if player.talking:
		return
	
	# HUD outline drawing
	var originalVerticesArray = []
	
	var origin = mesh.get_global_transform().origin
	var point = null

	# both array meshes and primitive meshes have AABB
	for i in range(7):
		# use a fake (rotated) aabb instead for AI
		if target is KinematicBody:
			# this is global, to take rotation into account
			if target.is_in_group("civilian"):
				point = target.get_node("RotationHelper/model/Position3D").get_child(i).global_transform.origin
			else:
				point = target.get_node("RotationHelper/Character2/Armature/HitBoxTorso/center").get_child(i).global_transform.origin
			# so just plug it in
			originalVerticesArray.append(point)
#			mesh.get_transformed_aabb().get_endpoint(i)
			#point = point.rotated(Vector3(1,0,0), deg2rad(45))
		elif target is StaticBody and target.has_node("Position3D"): # the door
			# this is global, to take rotation into account
			point = target.get_node("Position3D").get_child(i).global_transform.origin
			# so just plug it in
			originalVerticesArray.append(point)
		else:
			point = mesh.get_aabb().get_endpoint(i) # this is in local space
			originalVerticesArray.append(point + origin) # AABB are unrotated by design, so we can just add
			# FIXME: this means that rotated meshes show bad bounds
		
	# transform
	var unprojectedVerticesArray = []
	for p in originalVerticesArray:
		unprojectedVerticesArray.append(get_viewport().get_camera().unproject_position(p))
		
	# based on https://godotengine.org/qa/40175/get-screen-size-bounds-of-3d-mesh
	# init
	var p1 = unprojectedVerticesArray[0]
	var p2 = p1

	# pick min and max only
	for p in unprojectedVerticesArray:
		p1.x = min(p1.x, p.x)
		p1.y = min(p1.y, p.y)
		p2.x = max(p2.x, p.x)
		p2.y = max(p2.y, p.y)
		

	var start = p1
	var end = p2
	var width = abs(start.x-end.x)
	var height = abs(start.y-end.y)
	
	# send them to HUD
	#player.get_node("Control/ColorRect").rect_position = start
	#player.get_node("Control/ColorRect2").rect_position = end
	
	# small margin
	var margin = Vector2(4,4)
	
	player.get_node("Control/ReferenceRect").visible = true
	player.get_node("Control/ReferenceRect").rect_position = start - margin
	player.get_node("Control/ReferenceRect").set_size(Vector2(width+2*margin.x, height+2*margin.y))
	# show item name
	if target is KinematicBody and target.dead:
		player.get_node("Control/ReferenceRect/Label").set_text(target.get_name() + " (Dead)")
	elif target is KinematicBody and target.unconscious:
		player.get_node("Control/ReferenceRect/Label").set_text(target.get_name() + " (Unconscious)")
	else:
		player.get_node("Control/ReferenceRect/Label").set_text(target.get_name())


func detect_interactable():
	#print("Detect interactable...")
	# Get the raycast node
	var ray = $RayCast
	# interactable range is 4 m (to be slightly more generous, 2m range is more realistic but the majority of it is obscured by our arms/weapon)
	ray.cast_to = Vector3(0,0,-4) 
	ray.collision_mask = 1
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		#print("Colliding with: ", body.get_name())

		# dead AIs
		# TODO: clean this messy line up!
		if body is PhysicalBone:
			var character = body.get_node("../../../..")
			# bail early if we somehow detected the body we're carrying
			if 'carried' in character and character.carried:
				return
			
			if 'dead' in character and character.dead or 'unconscious' in character and character.unconscious and not 'player' in character:

				if last_interactable and is_instance_valid(last_interactable):
					var target = body
					draw_screen_outline(target.get_parent().get_node("Body"), target.get_node("../../../.."))
					#draw_screen_outline(target.get_child(1).get_node("Character2/Armature/Body"))
					if last_interactable != body:
						# remove outline from previous interactable
						var lt = last_interactable
						# AI don't have next pass set up
						if lt is Area or lt is RigidBody:
							if 'next_pass' in lt.get_child(1).get_surface_material(0):
								lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
						last_interactable = body.get_parent().get_parent().get_parent().get_parent() # the KinematicBody instead

						#target.get_child(1).get_node("Character2/Armature/Body").get_surface_material(0).next_pass.set_shader_param("thickness", 0.1)
				else:
					last_interactable = body.get_parent().get_parent().get_parent().get_parent() # the KinematicBody instead
					var target = body
					draw_screen_outline(target.get_parent().get_node("Body"), target.get_node("../../../.."))
					# AI don't have next pass set up
					#target.get_child(1).get_node("Character2/Armature/Body").get_surface_material(0).next_pass.set_shader_param("thickness", 0.1)
					#draw_screen_outline(target.get_child(1).get_node("Character2/Armature/Body"))

		# live NPCs
		elif body is KinematicBody and body.is_in_group("civilian") or body.is_in_group("ally"):
			if last_interactable and is_instance_valid(last_interactable):
				var target = body
				if body.is_in_group("civilian"):
					draw_screen_outline(target.get_node("RotationHelper/model/Human Armature/Skeleton/Human_Mesh"), body)
				if last_interactable != body:
					# remove outline from previous interactable
					var lt = last_interactable
					# AI don't have next pass set up
					if lt is Area or lt is RigidBody:
						if 'next_pass' in lt.get_child(1).get_surface_material(0):
							lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
					last_interactable = body
			else:
				last_interactable = body
				var target = body
				if body.is_in_group("civilian"):
					draw_screen_outline(target.get_node("RotationHelper/model/Human Armature/Skeleton/Human_Mesh"), body)
				# ally doesn't draw an outline, for now	
					
		# interactable items
		# doors are StaticBodies ;)
		elif (body is Area or body is RigidBody or body is StaticBody) and body.is_in_group("interactable"):
			if last_interactable and is_instance_valid(last_interactable):
				var target = body
				draw_screen_outline(target.get_child(1), target)
				if last_interactable != body:
					# remove outline from previous interactable
					var lt = last_interactable
					# AI don't have next pass set up
					if lt is Area or lt is RigidBody:
						if lt.get_child(1).get_surface_material(0).get_next_pass() != null:
							lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
					last_interactable = body
					if target.get_child(1).get_surface_material(0).get_next_pass() != null:
						target.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0.1)

			else:
				last_interactable = body
				var target = body
				if target.get_child(1).get_surface_material(0).get_next_pass() != null:
					target.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0.1)
				draw_screen_outline(target.get_child(1), target)
				
				
		else:
			if last_interactable and is_instance_valid(last_interactable):
				# remove outline from previous interactable
				var lt = last_interactable
				# AI don't have next pass set up
				if lt is Area or lt is RigidBody:
					if lt.get_child(1).get_surface_material(0).get_next_pass() != null:
						lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
				last_interactable = null
				player.get_node("Control/ReferenceRect").hide()
	else:
		if last_interactable and is_instance_valid(last_interactable):
			# remove outline from previous interactable
			var lt = last_interactable
			# AI don't have next pass set up
			if lt is Area or lt is RigidBody:
				if lt.get_child(1).get_surface_material(0).get_next_pass() != null:
					lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
			last_interactable = null
			player.get_node("Control/ReferenceRect").hide()

func iff():
	# Get the raycast node
	var ray = $RayCast
	# same range as ranged weapons
	ray.cast_to = Vector3(0,0,-50)
	# we want to detect AIs 
	ray.collision_mask = 1
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		#print("body:", body)
		if body is KinematicBody:
			if body.is_in_group("civilian"):
				# neutral
				# white
				player.get_node("Control/Center/Crosshair").set_color(Color(1,1,1))
				player.get_node("Control/Center/Control").set_self_modulate(Color(1,1,1))
			elif body.is_in_group("ally"):
				# friendly
				var env = get_tree().get_nodes_in_group("root")[0].get_node("WorldEnvironment").environment
				if !env.is_adjustment_enabled():
					player.get_node("Control/Center/Crosshair").set_color(Color(0,1,0))
					player.get_node("Control/Center/Control").set_self_modulate(Color(0,1,0))
				else:
					# shades of green are invisible when NV is on, so....
					# blue/cyan is a common equivalent of green in colorblind palettes
					# plus the MC and allies have a blue visor
					player.get_node("Control/Center/Crosshair").set_color(Color(0,1,1))
					player.get_node("Control/Center/Control").set_self_modulate(Color(0,1,1))
			else:
				# hostile
				player.get_node("Control/Center/Crosshair").set_color(Color(1,0,0))
				player.get_node("Control/Center/Control").set_self_modulate(Color(1,0,0))
		else:
			# we detected something else, default to orange (visible on both normal and NV vision)
			player.get_node("Control/Center/Crosshair").set_color(Color(1,0.5,0))
			player.get_node("Control/Center/Control").set_self_modulate(Color(1,0.5,0))
