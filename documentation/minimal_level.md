# Minimal level explaination

- Boid System
	- Main controller for the boids 
	- Configuration edits:
		- Changed the rng seed
		- Ground = "Boid Ground" (Flat Height = 0)
		- Obstacle Sources = one BoidObstacleSourceWorld (Collision Mask = 2)
		- Profiles = sheep_behaviour.tres
		- World Bounds: looking at the level from above, the values are for x, z, width and depth of the area.
			This should be set for the outer most fences, but if collision for the gridmap works then it is not relevant

- Boid Presenter
	- Has the role of displaying the boids 
	- Configuration edits:
		- System = Boid System in the scene 
		- Visuals = sheep_visual.tres

- Level Manager:
	- Determines when the player has successfully completed the level
	- Configuration edits:
		- System = Boid system in the scene
		- Pens = collection of all boid pens in the scene 

- Player
	- Configuration edits:
		- System = Boid System in the scene 

- Ground
	- Configuration: 
		- Has to have a StaticBody3D just for the player, the boids do not directly react (ground is set to 0 in main system)

- GridMap
	- Configuration:
		- Mesh Library = walls.tres
		- Collision layer: 2

- BoidPen
	- Configuration:
		- System = Boid System in the scene 
