class_name BoidStageTimer
extends RefCounted

var names: PackedStringArray
var ticks := 0
var _t0 := PackedInt64Array()
var _sum := PackedInt64Array()
var _max := PackedInt64Array()
var _tick_t0 := 0
var _tick_sum := 0
var _tick_max := 0


func _init(stage_names: PackedStringArray) -> void:
	names = stage_names
	_t0.resize(names.size())
	_sum.resize(names.size())
	_max.resize(names.size())


func reset() -> void:
	ticks = 0
	_sum.fill(0)
	_max.fill(0)
	_tick_sum = 0
	_tick_max = 0


func begin_tick() -> void:
	_tick_t0 = Time.get_ticks_usec()


func end_tick() -> void:
	var d := Time.get_ticks_usec() - _tick_t0
	_tick_sum += d
	if d > _tick_max:
		_tick_max = d
	ticks += 1


func begin(stage: int) -> void:
	_t0[stage] = Time.get_ticks_usec()


func end(stage: int) -> void:
	var d := Time.get_ticks_usec() - _t0[stage]
	_sum[stage] += d
	if d > _max[stage]:
		_max[stage] = d


func avg_ms(stage: int) -> float:
	return (_sum[stage] / 1000.0) / maxf(ticks, 1)


func tick_avg_ms() -> float:
	return (_tick_sum / 1000.0) / maxf(ticks, 1)


func summary() -> String:
	var lines := PackedStringArray()
	lines.append("stage          avg ms    max ms   (%d ticks)" % ticks)
	for i in names.size():
		lines.append("%s %8.3f  %8.3f" % [names[i].rpad(14), avg_ms(i), _max[i] / 1000.0])
	lines.append("%s %8.3f  %8.3f" % ["TOTAL".rpad(14), tick_avg_ms(), _tick_max / 1000.0])
	return "\n".join(lines)
