class_name BoidSpawnConfig
extends Resource
## Describes one group of boids to spawn: species, how many, and their starting state, heading and speed.

## How the initial heading of each spawned boid is chosen.
enum HeadingPolicy { 
	## Each boid gets a random heading.
	RANDOM, 
	## Every boid uses fixed_heading_degrees.
	FIXED, 
	## Each boid faces away from the spawn center.
	RADIAL_OUT, 
	## Each boid faces toward the spawn center.
	TOWARD_CENTER 
}

## Species of the boids to spawn
@export var species: StringName = &"sheep"
## Number of boids of this species to spawn.
@export_range(0, 100000) var count := 100
## Name of the state the boids start in. Should match a state the BoidSystem
## knows about.
@export var initial_state: StringName = &"idle"
## How the initial heading of each boid is chosen. See HeadingPolicy.
@export var heading_policy: HeadingPolicy = HeadingPolicy.RANDOM
## Heading in degrees, used only when heading_policy is FIXED. Ignored by the other policies.
@export_range(-180.0, 180.0) var fixed_heading_degrees := 0.0
## Speed each boid starts with, in world units per second.
@export var initial_speed := 0.0
