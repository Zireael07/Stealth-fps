# steering behaviors implementation
extends Spatial

# class member variables go here, for example:
var velocity = Vector2(0,0)
var steer = Vector2(0,0)
var desired = Vector2(0,0)

var MAX_FORCE = 3 #4

var dist = 0.0

# match the ones in player.gd
const GRAVITY = -24.8
const MAX_SPEED = 4 #20 # 4 m/s is human walking speed
const JUMP_SPEED = 18
const ACCEL = 1 #4.5

export(Vector3) var target = Vector3(20, 0, 20) # dummy


func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	
	pass

func _physics_process(delta):
	pass

# ------------------------------------------
# steering behaviors
func seek(target):
	# make the code universal
	# can be passed both a vector2 or a node
	if not typeof(target) == TYPE_VECTOR3:
		if "translation" in target:
			# steering behaviors operate in local space
			var tr = to_local(target.get_global_transform().origin)
			target = Vector2(tr.x, tr.z) #get_global_position())
	
#	print("tg: " + str(target))
#	print("position: " + str(get_global_position()))
	
	var steering = Vector2(0,0)
	#print("Tg: " + str(target_obj.get_position()) + " " + str(get_position()))
	
	desired = target - Vector2(get_translation().x, get_translation().z)
	dist = desired.length()
#	print("des: " + str(desired))
	desired = desired.normalized() * MAX_SPEED
	#print("max speed des: " + str(desired))
	#print("vel " + str(velocity))
	# desired minus current vel
	steering = (desired - velocity).clamped(MAX_FORCE)
	#print(str(steering))
	#steering = steering.clamped(max_force)
	#print(str(steering))
	
	return(steering)

func arrive(target, slowing_radius):
	# make the code universal
	# can be passed both a vector3 or a node
	if not typeof(target) == TYPE_VECTOR3:
		if "translation" in target:
			# steering behaviors operate in local space
			var tr = to_local(target.get_global_transform().origin)
			target = Vector2(tr.x, tr.z) #get_global_position())
	if typeof(target) == TYPE_VECTOR3:
		target = Vector2(target.x, target.z)
	
	var steering = Vector2(0,0)
	#print("Arrive @: " + str(target) + " " + str(get_translation()))

	desired = target - Vector2(get_translation().x, get_translation().z)
	#print("Desired " + str(desired))
	dist = desired.length()
	#print("Dist: " + str(dist))
	
	if dist < slowing_radius:
#		print("Slowing... " + str(dist/slowing_radius))
		# inside slowing area
		desired = desired.normalized() * MAX_SPEED * (dist / slowing_radius)
		
	else:
		#print("Not slowing")
		# outside
		desired = desired.normalized() * MAX_SPEED

	# desired minus current vel
	steering = (desired - velocity).clamped(MAX_FORCE)
	#print("Steering", steering)

	return (steering)
