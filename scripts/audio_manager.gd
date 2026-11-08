class_name AudioManager
extends Node

@export var background_tracks: Array[AudioStream]
@export var sfx_descriptions: Array[SFXDescriptor]

@onready var bgm = $"BGM Stream Player"
@onready var sfx = $"SFX Stream Player"

func next_bgm():
	bgm.stop()
	var index = int(randf()*background_tracks.size())
	bgm.stream = background_tracks[index]
	bgm.play()

func stop_bgm():
	bgm.stop()

func trigger_sfx(id: StringName, variant: int = -1):
	for desc in sfx_descriptions:
		# Yes the case where variant = -1 has been considered in this if case
		if desc.id == id && variant < desc.variants.size():
			var index: int
			if variant == -1:
				index = int(randf()*desc.variants.size())
			else:
				index = variant
			
			# This might cause some problems when sfx overlap
			sfx.stop()
			sfx.stream = desc.variants[index]
			sfx.play()
				
			return
	push_error("[Audio Manager] could not play sfx with id %s" % id)

func on_bgm_stream_player_finished() -> void:
	next_bgm()
