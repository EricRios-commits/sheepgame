class_name BoidBehaviourTable
extends RefCounted
## Flat, array-indexed compilation of the authored profiles 

var n_species := 1
var n_states := 1
var group_count := 1

var entry_start := PackedInt32Array()
var entry_runtime: Array[BoidInfluenceRuntime] = []
var entry_weight := PackedFloat32Array()
var entry_layer := PackedInt32Array()
var max_speed := PackedFloat32Array()
var max_accel := PackedFloat32Array()

var tr_start := PackedInt32Array()
var tr_to := PackedInt32Array()
var tr_trigger := PackedInt32Array()
var tr_emitter_kind := PackedInt32Array()
var tr_dist2 := PackedFloat32Array()
var tr_seconds := PackedFloat32Array()
var tr_min_time := PackedFloat32Array()

var has_interactions := false
var ix_cohesion := PackedFloat32Array()
var ix_alignment := PackedFloat32Array()
var ix_separation := PackedFloat32Array()

var max_query_radius := 0.5


static func build(sys: BoidSystem) -> BoidBehaviourTable:
	var t := BoidBehaviourTable.new()
	var vocab := sys.vocab
	var fallback := sys.default_profile
	var profiles: Array[BoidSpeciesProfile] = []
	for p in sys.profiles:
		if p != null:
			profiles.append(p)
	vocab.state_id(BoidSystem.PENNED_STATE)
	vocab.state_id(BoidSystem.DEAD_STATE)
	var all := profiles.duplicate()
	if fallback != null:
		all.append(fallback)
	for p in all:
		for sb in p.states:
			if sb == null:
				continue
			vocab.state_id(sb.state)
			for tr in sb.transitions:
				vocab.state_id(tr.to_state)
	for p in profiles:
		vocab.species_id(p.species)
	if sys.interactions != null:
		for e in sys.interactions.entries:
			vocab.species_id(e.species_a)
			vocab.species_id(e.species_b)
	t.n_species = maxi(vocab.species_names.size(), 1)
	t.n_states = maxi(vocab.state_names.size(), 1)
	t.group_count = t.n_species * t.n_states
	var by_species := {}
	for p in profiles:
		by_species[p.species] = p
	for sp in t.n_species:
		var sname: StringName = vocab.species_names[sp] if sp < vocab.species_names.size() else &""
		var prof: BoidSpeciesProfile = by_species.get(sname, fallback)
		for st in t.n_states:
			var stname: StringName = vocab.state_names[st] if st < vocab.state_names.size() else &""
			var sb: BoidStateBehaviour = null
			if stname == BoidSystem.PENNED_STATE or stname == BoidSystem.DEAD_STATE:
				t._add_group(sys, null)
				continue
			if prof != null:
				sb = prof.find_state(stname)
				if sb == null and not prof.states.is_empty():
					sb = prof.states[0]
					push_warning("BoidSystem: species '%s' has no behaviour for state '%s'; using '%s'." % [sname, stname, sb.state])
			t._add_group(sys, sb)
	t.entry_start.append(t.entry_runtime.size())
	t.tr_start.append(t.tr_to.size())
	var n2 := t.n_species * t.n_species
	t.ix_cohesion.resize(n2)
	t.ix_alignment.resize(n2)
	t.ix_separation.resize(n2)
	t.ix_cohesion.fill(1.0)
	t.ix_alignment.fill(1.0)
	t.ix_separation.fill(1.0)
	if sys.interactions != null and not sys.interactions.entries.is_empty():
		t.has_interactions = true
		for e in sys.interactions.entries:
			var idx := vocab.species_id(e.species_a) * t.n_species + vocab.species_id(e.species_b)
			t.ix_cohesion[idx] = e.cohesion
			t.ix_alignment[idx] = e.alignment
			t.ix_separation[idx] = e.separation
	return t


func _add_group(sys: BoidSystem, sb: BoidStateBehaviour) -> void:
	entry_start.append(entry_runtime.size())
	tr_start.append(tr_to.size())
	if sb == null:
		max_speed.append(4.0)
		max_accel.append(6.0)
		return
	max_speed.append(sb.max_speed)
	max_accel.append(sb.max_accel)
	for e in sb.influences:
		if e == null or e.influence == null:
			continue
		var rt := e.influence.create_runtime()
		if rt == null:
			continue
		rt.setup(sys)
		entry_runtime.append(rt)
		entry_weight.append(e.weight)
		entry_layer.append(e.influence.layer)
		max_query_radius = maxf(max_query_radius, e.influence.neighbour_radius())
	for tr in sb.transitions:
		tr_to.append(sys.vocab.state_id(tr.to_state))
		tr_trigger.append(tr.trigger)
		tr_emitter_kind.append(sys.vocab.emitter_kind_id(tr.emitter_kind))
		tr_dist2.append(tr.distance * tr.distance)
		tr_seconds.append(tr.seconds)
		tr_min_time.append(tr.min_time_in_state)