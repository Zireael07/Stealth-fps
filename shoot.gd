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
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		
		if body is StaticBody:
			#print("hit: ", body.get_parent().get_name().find("target"))
			create_bulletimpact(ray.get_collision_point(), ray.get_collision_normal(), 
			body.get_parent().get_name().find("target") != -1, true)
		if body is KinematicBody:
			body.die()
		
# -----------------------------------
# interactables use raycasting, so this code is also here
func draw_screen_outline(mesh, target):
	# HUD outline drawing
	var originalVerticesArray = []
	
	var origin = mesh.get_global_transform().origin
	var point = null

	# both array meshes and primitive meshes have AABB
	for i in range(7):
		# use a fake (rotated) aabb instead for AI
		if target is KinematicBody:
			# this is global, to take rotation into account
			point = target.get_node("RotationHelper/Character2/Armature/HitBoxTorso/center").get_child(i).global_transform.origin
			# so just plug it in
			originalVerticesArray.append(point)
#			mesh.get_transformed_aabb().get_endpoint(i)
			#point = point.rotated(Vector3(1,0,0), deg2rad(45))
		else:
			point = mesh.get_aabb().get_endpoint(i) # this is in local space
			originalVerticesArray.append(point + origin) # AABB are unrotated by design, so we can just add
		
		


	
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
	else:
		player.get_node("Control/ReferenceRect/Label").set_text(target.get_name())


func detect_interactable():
	#print("Detect interactable...")
	# Get the raycast node
	var ray = $RayCast
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		#print("Colliding with: ", body.get_name())

		# dead AIs
		# TODO: clean this messy line up!
		if body is PhysicalBone and \
		'dead' in body.get_node("../../../..") and body.get_node("../../../..").dead and not 'player' in body.get_node("../../../.."):
		#if body is KinematicBody and not 'player' in body and body.dead:
			if last_interactable:
				var target = body
				draw_screen_outline(target.get_parent().get_node("Body"), target.get_node("../../../.."))
				#draw_screen_outline(target.get_child(1).get_node("Character2/Armature/Body"))
				if last_interactable != body:
					# remove outline from previous interactable
					var lt = last_interactable
					# AI don't have next pass set up
					if lt is Area or lt is RigidBody:
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

		# interactable items
		elif (body is Area or body is RigidBody) and body.is_in_group("interactable"):
			if last_interactable:
				var target = body
				draw_screen_outline(target.get_child(1), target)
				if last_interactable != body:
					# remove outline from previous interactable
					var lt = last_interactable
					# AI don't have next pass set up
					if lt is Area or lt is RigidBody:
						lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
					last_interactable = body
					target.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0.1)

			else:
				last_interactable = body
				var target = body
				target.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0.1)
				draw_screen_outline(target.get_child(1), target)
				
				
		else:
			if last_interactable:
				# remove outline from previous interactable
				var lt = last_interactable
				# AI don't have next pass set up
				if lt is Area or lt is RigidBody:
					lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
				last_interactable = null
				player.get_node("Control/ReferenceRect").hide()
	else:
		if last_interactable:
			# remove outline from previous interactable
			var lt = last_interactable
			# AI don't have next pass set up
			if lt is Area or lt is RigidBody:
				lt.get_child(1).get_surface_material(0).next_pass.set_shader_param("thickness", 0)
			last_interactable = null
			player.get_node("Control/ReferenceRect").hide()
