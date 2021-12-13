extends "boid.gd"

# Declare member variables here. Examples:
# FSM
onready var state = PatrolState.new(get_parent())
var prev_state

const STATE_PATROL = 1

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
	emit_signal("state_changed", self)

func get_state():
	if state is PatrolState:
		return STATE_PATROL

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
	
		# rotations if any
		ch.rotate_y(deg2rad(ch.brain.steer.x * ch.STEER_SENSITIVITY))  #* -1))
