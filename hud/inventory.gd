extends Control


# Declare member variables here. Examples:
var player


# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_parent().get_parent()
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func update_slot(item):
	var opt = ""
	if item.slot == "GRENADE":
		opt = $"VBoxContainer/HBoxGrenade1/OptionButton"
		opt.add_item(item.get_name(), 0)
		# because index and id don't necessarily match up
		opt.set_item_metadata(opt.get_item_index(0), item)
		
	if item.slot == "GRENADE2":
		opt = $"VBoxContainer/HBoxGrenade2/OptionButton2"
		opt.add_item(item.get_name(), 0)
		# because index and id don't necessarily match up
		opt.set_item_metadata(opt.get_item_index(0), item)
		
		#$"VBoxContainer/HBoxGrenade1/OptionButton".select($"VBoxContainer/HBoxGrenade1/OptionButton".get_item_index(0))

# has to be done last to avoid mismatches
func select_item(item):
	var opt = ""
	if item.slot == "GRENADE":
		opt = $"VBoxContainer/HBoxGrenade1/OptionButton"
	if item.slot == "GRENADE2":
		opt = $"VBoxContainer/HBoxGrenade2/OptionButton2"
	# because index and id don't necessarily match up
	opt.select(opt.get_item_index(0))

func update_others(item):
	if item.slot == "GRENADE":
		# add to the OTHER button
		if $"VBoxContainer/HBoxGrenade2/OptionButton2".get_item_count() < 2:
			$"VBoxContainer/HBoxGrenade2/OptionButton2".add_item(item.get_name(), 1)
			# because index and id don't necessarily match up
			$"VBoxContainer/HBoxGrenade2/OptionButton2".set_item_metadata($"VBoxContainer/HBoxGrenade2/OptionButton2".get_item_index(1), item)
			
	if item.slot == "GRENADE2":
		# add to the OTHER button
		if $"VBoxContainer/HBoxGrenade1/OptionButton".get_item_count() < 2:
			$"VBoxContainer/HBoxGrenade1/OptionButton".add_item(item.get_name(), 1) 
			# because index and id don't necessarily match up
			$"VBoxContainer/HBoxGrenade1/OptionButton".set_item_metadata($"VBoxContainer/HBoxGrenade1/OptionButton".get_item_index(1), item)
			
			
# -------------------------------------------------
# makes the inventory menus work!
func _on_OptionButton_item_selected(index):
	var opt = $"VBoxContainer/HBoxGrenade1/OptionButton"
	var item = opt.get_item_metadata(index)
	item.slot = "GRENADE"
	player.inventory["GRENADE"] = item
	
	# update and swap if item is selected in the other slot
	var other = $"VBoxContainer/HBoxGrenade2/OptionButton2"
	if other.get_selected_metadata() == item:
		var other_it = null
		if other.selected == 0:
			other.select(1)
			other_it = other.get_item_metadata(1)
		elif other.selected == 1:
			other.select(0)
			other_it = other.get_item_metadata(0)
			
		other_it.slot = "GRENADE2"
		player.inventory["GRENADE2"] = other_it
	


func _on_OptionButton2_item_selected(index):
	var opt = $"VBoxContainer/HBoxGrenade2/OptionButton2"
	var item = opt.get_item_metadata(index)
	item.slot = "GRENADE2"
	player.inventory["GRENADE2"] = item
	
	# update and swap if item is selected in the other slot
	var other = $"VBoxContainer/HBoxGrenade1/OptionButton"
	if other.get_selected_metadata() == item:
		#print("Need to swap items... id", str(other.get_selected_id()), str(other.selected))
		var other_it = null
		if other.selected == 0:
			#print("Selected was 0, selecting 1")
			other.select(1)
			other_it = other.get_item_metadata(1)
		elif other.selected == 1:
			#print("Selected was 1, selecting 0")
			other.select(0)
			other_it = other.get_item_metadata(0)
			
		other_it.slot = "GRENADE"
		player.inventory["GRENADE"] = other_it


func _on_OptionButtonU_item_selected(index):
	player._on_uniform_change(index)
	#pass # Replace with function body.
