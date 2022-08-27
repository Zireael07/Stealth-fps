# based on https://godotforums.org/d/27752-making-doom-3-style-computers-and-terminals/7

extends Spatial

export (NodePath) var cursor_sprite

var quad_mesh_size
var is_mouse_inside = false
var is_mouse_held = false
var last_mouse_pos3D = null
var last_mouse_pos2D = null
var virutal_cursor = null

onready var node_viewport = $Viewport
onready var node_quad = $Quad
#onready var node_area = $Quad/Area

func _ready():
	pass

func get_cursor():
	var player = get_tree().get_nodes_in_group("player")[0]
	var ray = player.camera.get_node("Spatial/RayCast")
	var cursor = ray.get_collision_point()
	self.virutal_cursor = cursor
	#print("Virt cursor is", cursor)

func too_far():
	var dist = 2
	# be more lenient on dist if we are parented to something else interactable
	if get_parent().is_in_group("interactable"):
		dist = 3
		
	var dst = get_tree().get_nodes_in_group("player")[0].global_transform.origin.distance_to(global_transform.origin)
	#print("Dist: ", dst)
	return dst > dist

func _process(_delta):
	if is_mouse_inside:
		get_cursor()
		
	if too_far() and is_mouse_inside:
		# disable
		is_mouse_inside = false
		$Quad.get_active_material(0).albedo_texture = null
		print("Moved too far away")
	pass

func _on_interact():
	# switch on - set the texture
	$Quad.get_active_material(0).albedo_texture = $Viewport.get_texture()
	
	#Target.owner.is_mouse_inside = true
	self.is_mouse_inside = true
	get_cursor()
	#Target.owner.virutal_cursor = cursor

func _input(event):
	var is_mouse_event = false
	for mouse_event in [InputEventMouseButton, InputEventMouseMotion, InputEventScreenDrag, InputEventScreenTouch]:
		if event is mouse_event:
			is_mouse_event = true
			break
			
	if is_mouse_event and (is_mouse_inside or is_mouse_held):
		handle_mouse(event)
	elif not is_mouse_event:
		node_viewport.input(event)


func handle_mouse(event):
	quad_mesh_size = node_quad.mesh.size

	if event is InputEventMouseButton or event is InputEventScreenTouch:
		is_mouse_held = event.pressed
	var mouse_pos3D = find_mouse()

	if is_mouse_inside:
		mouse_pos3D = $Quad.global_transform.affine_inverse() * mouse_pos3D
		last_mouse_pos3D = mouse_pos3D
	else:
		mouse_pos3D = last_mouse_pos3D
		if mouse_pos3D == null:
			mouse_pos3D = Vector3.ZERO


	var mouse_pos2D = Vector2(mouse_pos3D.x, -mouse_pos3D.y)
	
	
	mouse_pos2D.x += quad_mesh_size.x / 2
	mouse_pos2D.y += quad_mesh_size.y / 2

	mouse_pos2D.x = mouse_pos2D.x / quad_mesh_size.x
	mouse_pos2D.y = mouse_pos2D.y / quad_mesh_size.y


	mouse_pos2D.x = mouse_pos2D.x * node_viewport.size.x
	mouse_pos2D.y = mouse_pos2D.y * node_viewport.size.y

	event.position = mouse_pos2D
	event.global_position = mouse_pos2D

	last_mouse_pos2D = mouse_pos2D
	get_node(cursor_sprite).rect_position = last_mouse_pos2D 
	
	node_viewport.input(event)


func find_mouse():
	var result = virutal_cursor
	if result:
		return result
	else:
		return null
