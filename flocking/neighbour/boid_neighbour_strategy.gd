class_name BoidNeighbourStrategy
extends RefCounted
## Swappable neighbour search
##
## Contract:
##  - rebuild() once per tick from the store; reuses internal buffers.
##  - query() fills a caller-provided buffer (no allocation) with slots whose position is
##    within `radius` of `center` (inclusive), excluding `exclude_slot` (pass -1 to exclude
##    nothing). Returns the number written, never more than out.size().
##  - Radius filtering is guaranteed. Result order is deterministic: cell order, then slot order.
##  - Slots are valid only until the store is next modified (swap-remove moves them).


func rebuild(_store: BoidStore, _max_query_radius: float) -> void:
	pass


func query(_center: Vector2, _radius: float, _exclude_slot: int, _out: PackedInt32Array) -> int:
	return 0