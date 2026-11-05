extends Node3D

@export var boid_system: BoidSystem
# Is this the best way to handle it or should this script scan the scene automatically?

@export var starPercentages: Array[float] = [0.6, 0.8, 1]

class AmountPerSpecies:
	var total: int
	var insideCorrectBarn = 0
	var insideWrongBarn = 0
	
	func _init(total: int):
		self.total = total

var stats : Dictionary[int, AmountPerSpecies] # Species id to Amount

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if boid_system == null:
		push_warning("[Level Manager] '%s' has no system assigned; The level cannot be completed." % name)
		return
	boid_system.boid_penned.connect(_on_boid_penned)
	
	# Get info from pens
	if len(boid_system.pens) <= 0:
		push_warning("[Level Manager] Boid system has no pens assigned.")
		return;
	for pen in boid_system.pens:
		var species_id = boid_system.vocab.species_id(pen.correct_species)
		if stats.has(species_id):
			stats[species_id].total += pen.number_of_spots
		else:
			stats[species_id] = AmountPerSpecies.new(pen.number_of_spots)
	

func _on_boid_penned(pen_index: int, species_id: int):
	if boid_system == null:
		return
	var pen = boid_system.pens[pen_index]
	var pen_species_id = boid_system.vocab.species_id(pen.correct_species)
	
	if !stats.has(pen_species_id):
		push_error("[Level Manager] Pen with species id %d not found" % pen_species_id)
		return
	
	if pen_species_id == species_id:
		stats[species_id].insideCorrectBarn += 1
	else:
		stats[species_id].insideWrongBarn += 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var progress = 0
	var total_overall = 0
	for key in stats.keys():
		var stat = stats[key]
		progress += stat.insideCorrectBarn 
		# progress += stat.insideCorrectBarn + stat.insideWrongBarn / 2
		total_overall += stat.total
	
	var percentage = float(progress) / total_overall
	pass
	
