extends Spatial


# Declare member variables here. Examples:
var world_node = null
var bullet_impact = null


# Called when the node enters the scene tree for the first time.
func _ready():
	world_node = get_tree().get_nodes_in_group("root")[0]
	bullet_impact = preload("res://bullet_impact.tscn")


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
