class_name BoidInfluenceEntry
extends Resource
## One (influence, weight) line of a state's behaviour.

## Influence for this entry
@export var influence: BoidInfluence
## Multiplier on top of influence result
@export var weight := 1.0