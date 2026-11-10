class_name PenBuilding
extends StaticBody3D
## Swings two doors open in opposite directions when a BoidPenStorage reports that it is full.

## Storage whose `filled` signal triggers the doors.
@export var storage: BoidPenStorage
## Door that rotates by +swing_degrees around the Y axis.
@export var left_door: Node3D
## Door that rotates by -swing_degrees around the Y axis.
@export var right_door: Node3D
## How far each door rotates, in degrees. The left door turns +, the right door turns -.
@export_range(0.0, 180.0, 0.5) var swing_degrees := 90.0
## Time the swing takes, in seconds. 0 rotates the doors instantly.
@export_range(0.0, 10.0, 0.05, "or_greater") var swing_seconds := 0.6
## Time to wait after the storage fills before the doors start swinging, in seconds.
@export_range(0.0, 30.0, 0.05, "or_greater") var swing_delay_seconds := 1.0
var _has_swung := false


func _ready() -> void:
	if storage == null:
		push_warning("BoidPenDoors '%s' has no storage assigned; the doors will not move." % name)
		return
	storage.filled.connect(_on_storage_filled)


func _on_storage_filled() -> void:
	if _has_swung:
		return
	_has_swung = true
	if swing_delay_seconds > 0.0:
		await get_tree().create_timer(swing_delay_seconds).timeout
	_swing_door(left_door, swing_degrees)
	_swing_door(right_door, -swing_degrees)


func _swing_door(door: Node3D, delta_degrees: float) -> void:
	if door == null:
		return
	var target_yaw_degrees := door.rotation_degrees.y + delta_degrees
	if swing_seconds <= 0.0:
		door.rotation_degrees.y = target_yaw_degrees
		return
	var swing_tween := create_tween()
	swing_tween.tween_property(door, "rotation_degrees:y", target_yaw_degrees, swing_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
