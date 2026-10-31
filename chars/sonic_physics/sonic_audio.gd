class_name SonicAudio
extends Node
## Toca sons a partir dos sinais do SonicPlayer usando o seu AudioStreamPlayer.
## Arraste os AudioStream nos campos. Eventos de habilidades vão em `extra_sounds`
## (chave = nome do evento, ex.: "spindash_charge" e "spindash_release").

@export var player: SonicPlayer                 ## vazio = pai
@export var audio_player: AudioStreamPlayer     ## vazio = primeiro AudioStreamPlayer do player
@export var jump: AudioStream
@export var roll: AudioStream
@export var hurt: AudioStream
@export var death: AudioStream
@export var land: AudioStream
@export var extra_sounds: Dictionary = {}
## O som de carga do spin dash sobe de tom a cada aperto.
@export var spindash_pitch_per_rev := 0.06


func _ready() -> void:
	if player == null:
		player = get_parent() as SonicPlayer
	if player == null:
		push_warning("SonicAudio: sem SonicPlayer.")
		return
	if audio_player == null:
		for c in player.get_children():
			if c is AudioStreamPlayer:
				audio_player = c
				break
	player.jumped.connect(func(): _play(jump))
	player.started_rolling.connect(func(): _play(roll))
	player.got_hurt.connect(func(): _play(hurt))
	player.died.connect(func(): _play(death))
	player.landed.connect(func(): _play(land))
	player.ability_event.connect(_on_ability_event)


func _on_ability_event(event: StringName, data: Variant) -> void:
	var stream := extra_sounds.get(str(event)) as AudioStream
	if stream == null:
		stream = extra_sounds.get(event) as AudioStream
	var pitch := 1.0
	if event == &"spindash_charge":
		pitch = 1.0 + float(data) * spindash_pitch_per_rev
	_play(stream, pitch)


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if stream == null or audio_player == null:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = pitch
	audio_player.play()
