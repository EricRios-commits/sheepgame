extends Node3D

@export var boid_system: BoidSystem
# Is this the best way to handle it or should this script scan the scene automatically?
@export var pens: Array[BoidPen]

@export var starPercentages: Array[float] = [0.6, 0.8, 1]
var totalCount = 0
var insidePens = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if boid_system == null:
		push_warning("Level Manager '%s' has no system assigned; The level cannot be completed." % name)
		return
	boid_system.boid_penned.connect(_on_boid_penned)
	
	# Get info from pens
	if len(pens) <= 0:
		push_warning("Level Manager %s has no pens assigned.")
		return;
	for pen in pens:
		totalCount += pen.number_of_spots
	

func _on_boid_penned(pen_index: int, specie_id: int):
	insidePens += 1
	print("%d \t %d (%f)%%" % [insidePens, totalCount, ( float(insidePens) / totalCount) * 100])
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# update gui
	pass
	
