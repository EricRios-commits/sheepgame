class_name BoidTransition
extends Resource
## State change trigger. Evaluated after integration, queued, applied in Commit

## What a transition waits for.
enum Trigger {
	## Fires when an active emitter (of emitter_kind, if set) is within distance of the boid.
	EMITTER_NEAR,
	## Fires when no active emitter (of emitter_kind, if set) is within distance of the boid.
	EMITTER_FAR,
	## Fires once the boid has been in its current state for at least seconds.
	TIMER,
}

## State the boid switches to when this transition fires (e.g. "idle"). Should match a state
## the BoidSystem knows about. Special states: "penned" freezes the boid, "dead" removes it.
@export var to_state: StringName = &"idle"
## What condition fires this transition. See Trigger.
@export var trigger: Trigger = Trigger.EMITTER_NEAR
## Only emitters of this kind (see BoidEmitter.kind) are considered. Leave empty to consider
## emitters of any kind. Only used by EMITTER_NEAR and EMITTER_FAR.
@export var emitter_kind: StringName = &""
## Distance to an emitter, in world units, that counts as near. Only used by EMITTER_NEAR and
## EMITTER_FAR.
@export var distance := 10.0
## Time in seconds the boid must spend in its current state before this transition fires.
## Only used by TIMER.
@export var seconds := 5.0
## Minimum time in seconds the boid must have spent in its current state before an emitter
## trigger can fire. Only used by EMITTER_NEAR and EMITTER_FAR. TIMER ignores it.
@export var min_time_in_state := 0.0
