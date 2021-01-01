extends Spatial

# Variables
var timeout = 0.0;
var show_bullethole = true;
var keep = false

func _ready():
	# Emit particles
	$spark.emitting = true;
	$dust.emitting = true;
	
	# Set timeout
	randomize()
	timeout = rand_range(5.0, 8.0);
	
	if (show_bullethole):
		$mesh.show();
	else:
		$mesh.hide();

func _process(delta):
	if keep:
		return;
	
	# Count down without using a timer node :)
	if (timeout > 0.0):
		timeout -= delta;
		return;
	
	# Remove node
	if not keep:
		queue_free();

func bullet_hole(visible):
	# Set mesh visibility
	show_bullethole = visible;
