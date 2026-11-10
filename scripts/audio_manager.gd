class_name AudioManager
extends Node

@export var background_tracks: Array[AudioStream]
@export var sfx_descriptions: Array[SFXDescriptor]

@onready var bgm = $"BGM Stream Player"
var last_bgm_index = -1

func _ready() -> void:
	AudioServer.set_bus_volume_db(0, -12)
	for i in sfx_descriptions.size():
		var desc = sfx_descriptions[i];
		AudioServer.add_bus(i + 2)
		AudioServer.set_bus_name(i + 2, desc.id)
		var dedicated_player = AudioStreamPlayer.new()
		dedicated_player.bus = desc.id
		add_child(dedicated_player)
		desc.player = dedicated_player

func next_bgm():
	bgm.stop()
	var index = int(randf()*background_tracks.size())
	while index == last_bgm_index:
		index = int(randf()*background_tracks.size())
	bgm.stream = background_tracks[index]
	last_bgm_index = index
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
			desc.player.stop()
			desc.player.stream = desc.variants[index]
			desc.player.play()
				
			return
	push_error("[Audio Manager] could not play sfx with id %s" % id)

func on_bgm_stream_player_finished() -> void:
	next_bgm()
