extends StaticBody


# Declare member variables here. Examples:
var button = ""
var display

# Called when the node enters the scene tree for the first time.
func _ready():
	display = get_node("Viewport/Label")


func _on_interact():
	# the keypad is DIEGETIC!
	var player = get_tree().get_nodes_in_group("player")[0]
	# Get the raycast node
	var ray = player.get_node("RotationHelper/Character/Armature/CameraBoneAttachment/Camera/Spatial/RayCast")
	# interactable range is 2 m (to be slightly more generous, 2m range is more realistic but the majority of it is obscured by our arms/weapon)
	ray.cast_to = Vector3(0,0,-2) 
	ray.collision_mask = 1
	# Force the raycast to update. This will force the raycast to detect collisions when we call it.
	# This means we are getting a frame perfect collision check with the 3D world.
	ray.force_raycast_update()

	# Did the ray hit something?
	if ray.is_colliding():
		var body = ray.get_collider()
		if body is StaticBody:
			# relative to the point that governs the overlay
			var point = body.get_node("overlay_Position3D").to_local(ray.get_collision_point())
			var dist = Vector2().distance_to(Vector2(point.x, point.y))
			#print("Point: ", point, " dist: ", dist)
			
			# highlight the correct key
			var loc = Vector2()
			if dist > 0.05:
				if point.y > 0 and point.y < 0.05:
					if point.x < 0:
						# button 4
						loc = Vector2(-0.075, 0)
						button = "4"
					else:
						# button 6
						loc = Vector2(0.075,0)
						button = "6"
				elif point.y > 0.05:
					if point.x < -0.01:
						loc = Vector2(-0.075, 0.1)
						button = "1"
					elif point.x > 0.01:
						loc = Vector2(0.075, 0.1)
						button = "3"
					else:
						loc = Vector2(0.0, 0.1)
						button = "2"
				else:
					if point.x < -0.01:
						loc = Vector2(-0.075, -0.1)
						button = "7"
					elif point.x > 0.01:
						loc = Vector2(0.075, -0.1)
						button = "9"
					else:
						loc = Vector2(0, -0.1)
						button = "8"
			elif dist < 0.05:
				loc = Vector2()
				button = "5"
			
			display.text = button
			#print("BUTTON ", button)
			
			
			# show the overlay
			body.get_node("overlay_Position3D/overlay").set_translation(Vector3(loc.x, loc.y, 0))
			body.get_node("overlay_Position3D/overlay").show()
			
	#pass
