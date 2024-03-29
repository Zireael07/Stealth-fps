extends "boid.gd"

# Declare member variables here. Examples:
# FSM
onready var state = PatrolState.new(get_parent())
var prev_state

const STATE_PATROL = 1
const STATE_DISENGAGE = 2
const STATE_IDLE = 3
const STATE_FOLLOW = 4
const STATE_ALARMED = 5
const STATE_SEARCH = 6
const STATE_AVOID_GREN = 7

signal state_changed

# human-readable states
var pretty_states = {
	1 : "patrol",
	2 : "disengage",
	3 : "idle",
	4 : "following",
	5 : "alarmed",
	6 : "search",
	7 : "avoiding grenades",
}

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
	if new_state == STATE_ALARMED:
		state = AlarmedState.new(get_parent())
	if new_state == STATE_SEARCH:
		state = SearchState.new(get_parent())
	if new_state == STATE_AVOID_GREN:
		state = AvoidGrenade.new(get_parent(), param)
	
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
	if state is AlarmedState:
		return STATE_ALARMED
	if state is SearchState:
		return STATE_SEARCH
	if state is AvoidGrenade:
		return STATE_AVOID_GREN

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
		# FIXME: AI sometimes "orbits" around the target
		#print("St: ", ch.brain.steer.x, " rot: ", deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))
		# possible fixes: look_at within 1.75m of target?
		ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))
		

class DisengageState:
	var ch
	var closest_hide
	var best_spot
	var enemy
	
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
		#ch.get_node("MeshInstance2").show()
		
		# if we have a hiding spot, go to it
		if self.closest_hide != 9999:
			# debug
			#print("Best spot: ", self.best_spot)
			#ch.get_node("MeshInstance2").set_translation(self.best_spot)
			
			# arrive to the spot w/o rotations
			ch.brain.steer = ch.brain.arrive(self.best_spot, 2)
			ch.strafe = true
			
			if ch.get_global_transform().origin.distance_to(Vector3(self.best_spot.x, 0, self.best_spot.z)) < 1.5:
				#print("Reached the hiding spot")
				ch.emit_signal("emit_bark", ch, "Now you can't see me!")
				# test
				ch.brain.target = ch.target_array[ch.current]
				ch.brain.set_state(ch.brain.STATE_PATROL)
				ch.strafe = false
				return
		
		#TODO: the minimum distance needs some noise and/or parameter
		elif ch.in_sight and ch.dist_to_target() < 5:
			self.enemy = ch.possible_tg
			# if we haven't done it yet
			if self.closest_hide == 9999:
				#find cover/break line of sight
				self.closest_hide = 9999
				self.best_spot = null
				for o in ch.get_tree().get_nodes_in_group("obstacle"):
					var hide = get_hiding(o, self.enemy)
					
					if ch.get_global_transform().origin.distance_to(hide) < self.closest_hide:
						self.closest_hide = ch.get_global_transform().origin.distance_to(hide)
						self.best_spot = hide
			
			# if no hiding spot found, just flee
			if self.closest_hide == 9999:
				#TODO: mix in some wander			
				ch.brain.steer = ch.brain.get_steering_flee(ch.brain.target)
			else:
				# debug
				#print("Best spot found: ", self.best_spot)
				#ch.get_node("MeshInstance2").set_translation(self.best_spot)
				
				# arrive to the spot w/o rotations
				ch.brain.steer = ch.brain.arrive(self.best_spot, 2)
				ch.strafe = true

		elif ch.in_sight:
			#print("Player in sight, be wary...")
			ch.strafe = true
			ch.brain.steer = Vector2(0,0.2)
			#ch.brain.steer = ch.brain.get_steering_arrive(get_global_position().origin-Vector3(0,0,1))
		else:
			#ch.get_node("MeshInstance2").hide()
			# no enemy in sight, no hiding spot, go back to patrol
			ch.brain.target = ch.target_array[ch.current]
			ch.brain.set_state(ch.brain.STATE_PATROL)
			ch.strafe = false
			ch.emit_signal("emit_bark", ch, "Can't see the guy! Going back to my patrol...")

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
		
		if typeof(ch.brain.target) == TYPE_VECTOR3:
			pass
		else:
			ch.brain.target = ch.brain.target.get_global_transform().origin
		
			
		ch.brain.steer = ch.brain.arrive(ch.brain.target, 3)
		
		# don't rotate if we're going backwards
		var rel_loc = ch.to_local(ch.brain.target)
		if rel_loc.z > 0:
			# rotations if any
			ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))

class AlarmedState:
	var ch
	
	func _init(cha):
		self.ch = cha
	
	func update(delta):
		# yellow indicator
		ch.get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, ch.alarmed_emote)
		
		ch.brain.steer = ch.brain.arrive(ch.brain.target, 3)
		ch.strafe = false
		
		# rotations if any
		ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))
		
		
		if ch.is_close_to_target(1.5):
			print("Reached button")
			#interact with it
			ch.get_tree().get_nodes_in_group("alarm")[0].get_child(0)._on_interact()

			ch.emit_signal("emit_bark", self, "Alarm raised! Going back to patrol...")
			ch.brain.target = ch.target_array[ch.current]
			ch.brain.set_state(ch.brain.STATE_PATROL)
			ch.strafe = false
			
class SearchState:
	var ch
	var seek_time
	var found = false
	
	func _init(cha):
		self.ch = cha
		self.seek_time = 10.0;
	
	func update(delta):
		ch.get_node("RotationHelper/MeshInstance").get_material_override().set_texture(0, ch.seen_emote)
		
		# count down
		self.seek_time = self.seek_time - delta
		
		ch.brain.steer = ch.brain.arrive(ch.last_seen_pos, 3)
		ch.strafe = false
		
		# rotations if any
		ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))
		
		if ch.is_close_to_target(2):
			# look around
			if ch.get_node("Timer2").is_stopped():
				ch.get_node("Timer2").start()
		
		# give up, go back to patrolling
		if self.seek_time <= 0:
			ch.get_node("Timer2").stop()
			ch.brain.target = ch.target_array[ch.current]
			ch.brain.set_state(ch.brain.STATE_PATROL)
			ch.emit_signal("emit_bark", self, "No one here... Going back to patrol...")
			
		if found:
			ch.get_node("Timer2").stop()
			ch.brain.target = ch.target_array[ch.current]
			ch.brain.set_state(ch.brain.STATE_PATROL)

class AvoidGrenade:
	var ch
	var grenade
	
	func _init(cha, nade):
		self.ch = cha
		self.grenade = nade
	
	func update(delta):
		if (self.grenade != null and is_instance_valid(self.grenade)) \
		and ch.dist_to_target() < 8:
			print("Fleeing from a grenade...")
			ch.brain.steer = ch.brain.get_steering_flee(self.grenade)
		else:
			if self.grenade == null or !is_instance_valid(self.grenade):
				# clear the flags
				ch.grenade_threat = null
				ch.emit_signal("emit_bark", self, "Danger has exploded!")
			
			if ch.dist_to_target() > 8:
				ch.grenade_threat = null
				ch.emit_signal("emit_bark", self, "Should be out of range now!")
				
			ch.brain.target = ch.target_array[ch.current]
			ch.brain.set_state(ch.brain.STATE_PATROL)
