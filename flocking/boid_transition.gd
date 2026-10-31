class_name BoidTransition
extends Resource
## State change trigger. Evaluated after integration, queued, applied in Commit

enum Trigger { EMITTER_NEAR, EMITTER_FAR, TIMER }

@export var to_state: StringName = &"idle"
@export var trigger: Trigger = Trigger.EMITTER_NEAR
@export var emitter_kind: StringName = &""
@export var distance := 10.0
@export var seconds := 5.0
@export var min_time_in_state := 0.0