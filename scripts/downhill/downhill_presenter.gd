extends BoidPresenter

var motion: RefCounted

func _sync_species() -> void:
	super._sync_species()
	for batch in _active + _frozen:
		batch.inst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _write_region(from: int, to: int, bufs: Array[PackedFloat32Array], a: float, frozen: bool) -> void:
	super._write_region(from, to, bufs, a, frozen)
	if frozen or motion == null:
		return
	var cursors := PackedInt32Array()
	cursors.resize(_n_species)
	for i in range(from, to):
		var sp := system.store.species[i]
		var o := cursors[sp] * STRIDE
		cursors[sp] += 1
		var b: PackedFloat32Array = bufs[sp]
		var h := system.store.handle_at(i)
		# Interpolate the exact trajectory endpoints used by swept hoop tests.
		b[o + 7] = motion.presentation_height(h, Vector2(b[o + 3], b[o + 11]), a) + _sp_yoff[sp] + motion.presentation_bounce(h, a)
		var angle: float = motion.presentation_spin(h, a)
		if angle > 0:
			var basis := Basis(Vector3(b[o], b[o + 4], b[o + 8]), Vector3(b[o + 1], b[o + 5], b[o + 9]), Vector3(b[o + 2], b[o + 6], b[o + 10]))
			var bounds: AABB = _active[sp].mm.mesh.get_aabb()
			var center := bounds.get_center()
			var old_basis := basis
			basis = basis * Basis(Vector3.BACK, angle)
			# Rotate about the actual body center, not the feet/asset origin.
			var origin := Vector3(b[o+3],b[o+7],b[o+11]) + old_basis*center - basis*center
			var lift := 0.0
			for corner in 8:
				var p := origin + basis*bounds.get_endpoint(corner)
				# Include the existing gait shader's bounded vertex sway/bob.
				lift = maxf(lift, motion.Rules.height(Vector2(p.x,p.z))+0.2-p.y)
			origin.y += lift
			b[o+3] = origin.x
			b[o+7] = origin.y
			b[o+11] = origin.z
			for row in 3:
				for col in 3:
					b[o + row * 4 + col] = basis[col][row]
