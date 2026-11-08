class_name LevelManager
extends Node3D

@export var boid_system: BoidSystem
@export var star_percentages: Array[float] = [0.6, 0.8, 1]
@export var progress_bar: ProgressBar
@export var star_indicator_scene: PackedScene

var last_percentage = 0
signal should_show_results(percentage: float, cutoffs: Array[float])

class AmountPerSpecies:
	var total: int
	var insideCorrectBarn = 0
	var insideWrongBarn = 0
	
	func _init(total_: int):
		self.total = total_

var stats : Dictionary[int, AmountPerSpecies] # Species id to Amount
var star_indicators: Array[StarIndicator]

func _ready() -> void:
	for star_percentage in star_percentages:
		var star_indicator = star_indicator_scene.instantiate()
		progress_bar.add_child(star_indicator)
		star_indicators.append(star_indicator)
	
	# BoidPen registers itself to the system on the first frame of execution, so 
	# depending on execution order not all pens will be present in the system when this starts
	# For this reason we delay for one frame
	call_deferred("_get_pens_from_system")
	Global.audio_manager.next_bgm()

func _get_pens_from_system():
	if boid_system == null:
		push_warning("[Level Manager] '%s' has no system assigned; The level cannot be completed." % name)
		return
	boid_system.boid_penned.connect(_on_boid_penned)
	
	# Get info from pens
	if len(boid_system.storages) <= 0:
		push_warning("[Level Manager] Boid system has no pens assigned.")
		return;
	for storage in boid_system.storages:
		var species_id = boid_system.vocab.species_id(storage.correct_species)
		if stats.has(species_id):
			stats[species_id].total += storage.number_of_spots
		else:
			stats[species_id] = AmountPerSpecies.new(storage.number_of_spots)
		print("%d has total of %d" % [species_id, storage.number_of_spots])

func _on_boid_penned(storage_index: int, species_id: int):
	if boid_system == null:
		return
	var pen := boid_system.storages[storage_index]
	if pen == null:
		return # Plain storage, not part of scoring
	var pen_species_id = boid_system.vocab.species_id(pen.correct_species)
	
	if !stats.has(pen_species_id):
		push_error("[Level Manager] Pen with species id %d not found" % pen_species_id)
		return
	
	if pen_species_id == species_id:
		stats[species_id].insideCorrectBarn += 1
	elif stats.has(species_id):
		stats[species_id].insideWrongBarn += 1
	
	Global.audio_manager.trigger_sfx("sheep_baa")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var progress = 0
	var total_overall = 0
	
	for key in stats.keys():
		var stat = stats[key]
		progress += stat.insideCorrectBarn + stat.insideWrongBarn / 3 # So that the player is less scammed
		total_overall += stat.total
	
	if total_overall == 0:
		return
	
	var percentage = float(progress) / total_overall
	if percentage == 1.0 && progress_bar.value < 1.0:
		# We have finished the level
		# I was too lazy to add another variable for the rising edge detection
		should_show_results.emit(percentage, star_percentages)
	
	progress_bar.value = percentage
	
	# Update star indicator positions
	var pb_width = progress_bar.get_rect().size.x
	for i in star_indicators.size():
		var this_percentage = star_percentages[i]
		star_indicators[i].position.x = this_percentage * pb_width
		star_indicators[i].set_star(percentage >= this_percentage)
		if last_percentage < this_percentage && percentage >= this_percentage:
			Global.audio_manager.trigger_sfx("star_achieved", i)
	
	last_percentage = percentage

func on_give_up_button() -> void:
	should_show_results.emit(progress_bar.value, star_percentages)
	
