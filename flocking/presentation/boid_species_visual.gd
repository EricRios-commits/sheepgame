class_name BoidSpeciesVisual
extends Resource
## How one species looks. Looked up by species name when the presenter starts.

@export var species: StringName = &"sheep"
@export var mesh: Mesh
## Optional. Leave empty to use the mesh's own surface materials.
@export var material: Material
@export var base_scale := 1.0
## +-fraction of random uniform scale per boid.
@export_range(0.0, 0.5, 0.01) var scale_jitter := 0.08
## World-space lift (use it if the mesh origin is not at the feet).
@export var y_offset := 0.0
## The mesh's forward axis is +Z (glTF convention). Use 180 for a mesh that faces -Z.
@export_range(-180.0, 180.0) var yaw_offset_degrees := 0.0
## Metres travelled per gait cycle. Drives the animation phase (feet do not slide).
@export_range(0.1, 10.0, 0.05, "or_greater") var stride_length := 1.0
## 0 = always upright, 1 = fully aligned to the ground normal.
@export_range(0.0, 1.0, 0.05) var ground_tilt := 1.0
@export var cast_shadow := true