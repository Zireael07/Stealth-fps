extends "boid.gd"

# Declare member variables here. Examples:
# FSM
onready var state = PatrolState.new(get_parent())
var prev_state

const STATE_PATROL = 1
const STATE_DISENGAGE = 2
const STATE_IDLE = 3
const STATE_FOLLOW = 4

signal state_changed


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# fsm
func set_state(new_state, param=null):
	# if we need to clean up
	#state.exit()
	prev_state = get_state()
	
	if new_state == STATE_PATROL:
		state = PatrolState.new(get_parent())
	if new_state == STATE_DISENGAGE:
		state = DisengageState.new(get_parent())
	if new_state == STATE_IDLE:
		state = IdleState.new(get_parent())
	if new_state == STATE_FOLLOW:
		state = FollowState.new(get_parent())
	
	emit_signal("state_changed", self)

func get_state():
	if state is PatrolState:
		return STATE_PATROL
	if state is DisengageState:
		return STATE_DISENGAGE
	if state is IdleState:
		return STATE_IDLE
	if state is FollowState:
		return STATE_FOLLOW

# just call the state
#func _physics_process(delta):
#	state.update(delta)
	
# states ----------------------------------------------------
class PatrolState:
	var ch # Character
	
	func _init(cha):
		self.ch = cha
	
	func update(delta):
		if not ch.brain or not is_instance_valid(ch.brain):
			return
			
		ch.brain.steer = ch.brain.arrive(ch.brain.target, 5)
		
		ch.strafe = false
		
		# rotations if any
		ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))

class DisengageState:
	var ch
	var closest_hide
	var best_spot
	
	func _init(cha):
		self.ch = cha
		self.closest_hide = 9999
	
	## based on https://github.com/sturdyspoon/unity-movement-ai/blob/master/Assets/UnityMovementAI/Scripts/Units/Movement/Hide.cs	
	func get_hiding(obstacle, enemy):
		## obstacle radius + distance from obstacle
		var distAway = 1 + 0.5;

		var dir = obstacle.get_global_transform().origin - enemy.get_global_transform().origin;
		dir = dir.normalized()
		
		# debug
		#ch.get_node("MeshInstance2").set_translation(obstacle.get_global_transform().origin)
		#ch.get_node("MeshInstance2").set_translation(Vector3(ch.to_local(obstacle.get_global_transform().origin)))

		return obstacle.get_global_transform().origin + (dir * distAway)
	
		
	func update(delta):
		ch.get_node("MeshInstance2").show()
		
		# if we have a hiding spot, go to it
		if self.closest_hide != 9999:
			# debug
			#print("Best spot: ", self.best_spot)
			ch.get_node("MeshInstance2").set_translation(self.best_spot)
			
			# arrive to the spot w/o rotations
			ch.brain.steer = ch.brain.arrive(self.best_spot, 2)
			ch.strafe = true
			
			if ch.get_global_transform().origin.distance_to(self.best_spot) < 1.5:
				#print("Reached the hiding spot")
				ch.emit_signal("emit_bark", ch, "Now you can't see me!")
				# test
				ch.brain.target = ch.target_array[ch.current]
				ch.brain.set_state(ch.brain.STATE_PATROL)
				ch.strafe = false
				return
		
		elif ch.in_sight and ch.dist_to_target() < 5:
			# if we haven't done it yet
			if self.closest_hide == 9999:
				#find cover/break line of sight
				self.closest_hide = 9999
				self.best_spot = null
				for o in ch.get_tree().get_nodes_in_group("obstacle"):
					var hide = get_hiding(o, ch.brain.target)
					
					if ch.get_global_transform().origin.distance_to(hide) < self.closest_hide:
						self.closest_hide = ch.get_global_transform().origin.distance_to(hide)
						self.best_spot = hide
			
			# if no hiding spot found, just flee
			if self.closest_hide == 9999:
				#TODO: mix in some wander			
				ch.brain.steer = ch.brain.get_steering_flee(ch.brain.target)
			else:
				# debug
				print("Best spot found: ", self.best_spot)
				ch.get_node("MeshInstance2").set_translation(self.best_spot)
				
				# arrive to the spot w/o rotations
				ch.brain.steer = ch.brain.arrive(self.best_spot, 2)
				ch.strafe = true

		else:
			#ch.get_node("MeshInstance2").hide()
			# no enemy in sight, no hiding spot, go back to patrol
			ch.brain.target = ch.target_array[ch.current]
			ch.brain.set_state(ch.brain.STATE_PATROL)
			ch.strafe = false

class IdleState:
	var ch
	
	func _init(cha):
		self.ch = cha
	
	func update(delta):
		# dummy
		ch.brain.target = ch.get_global_transform().origin

class FollowState:
	var ch # Character
	
	func _init(cha):
		self.ch = cha
	
	func update(delta):
		if not ch.brain or not is_instance_valid(ch.brain):
			return
			
		ch.brain.steer = ch.brain.arrive(ch.brain.target, 3)
		
		# don't rotate if we're going backwards
		var rel_loc = ch.to_local(ch.brain.target)
		if rel_loc.z > 0:
			# rotations if any
			ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))
