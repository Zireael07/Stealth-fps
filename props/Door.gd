
extends StaticBody

var animating = false

const CLOSED = 0
const OPEN = 1

export var locked = false
var state = CLOSED

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	# fake aabb for outlines
	var debug = get_node("Position3D")
	for i in range(7):
		var end_point = get_node("MeshInstance").get_aabb().get_endpoint(i) # local space
		 # because we're looking at relative to center of the mesh itself
		var point = get_node("MeshInstance").to_global(end_point)
		var pt = Position3D.new()
#		var msh = CubeMesh.new()
#		msh.size = Vector3(0.25, 0.25, 0.25)
#		var pt = MeshInstance.new()
#		pt.set_mesh(msh)
		debug.add_child(pt)
		pt.global_transform.origin =  point

func _on_interact():
	if !animating:
		if state == CLOSED:
			$AnimationPlayer.play("open")
		else:
			$AnimationPlayer.play_backwards("open")

func _on_AnimationPlayer_animation_finished(anim_name):
	animating = false

	if state == OPEN:
		state = CLOSED
	else:
		state = OPEN


func _on_AnimationPlayer_animation_started(anim_name):
	animating = true
