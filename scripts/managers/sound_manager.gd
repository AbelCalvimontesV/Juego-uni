extends Node

# Shared sound effects for the whole game. Every effect is a local WAV asset.
const SOUND_LIBRARY: Dictionary = {
	"ui_click": preload("res://assets/audio/ui_click.wav"),
	"ui_hover": preload("res://assets/audio/ui_hover.wav"),
	"ui_error": preload("res://assets/audio/ui_error.wav"),
	"timer_tick": preload("res://assets/audio/timer_tick.wav"),
	"swing_jab": preload("res://assets/audio/swing_jab.wav"),
	"swing_cross": preload("res://assets/audio/swing_cross.wav"),
	"swing_upper": preload("res://assets/audio/swing_upper.wav"),
	"impact_light": preload("res://assets/audio/impact_light.wav"),
	"impact_heavy": preload("res://assets/audio/impact_heavy.wav"),
	"block": preload("res://assets/audio/block.wav"),
	"knockout": preload("res://assets/audio/knockout.wav"),
	"dash": preload("res://assets/audio/dash.wav"),
	"footstep": preload("res://assets/audio/footstep.wav"),
	"round_bell": preload("res://assets/audio/round_bell.wav"),
	"round_end": preload("res://assets/audio/round_end.wav"),
	"save_success": preload("res://assets/audio/save_success.wav"),
	"heal": preload("res://assets/audio/heal.wav"),
	"critical_charge": preload("res://assets/audio/critical_charge.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
	"draw": preload("res://assets/audio/draw.wav")
}

const CROWD_STREAM: AudioStreamWAV = preload("res://assets/audio/crowd_ambience.wav")
const VOICE_COUNT := 16

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _crowd_player: AudioStreamPlayer
var _crowd_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "SFXVoice%02d" % i
		voice.bus = "Master"
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_voices.append(voice)

	_crowd_player = AudioStreamPlayer.new()
	_crowd_player.name = "RingCrowdAmbience"
	_crowd_player.stream = CROWD_STREAM
	_crowd_player.volume_db = -29.0
	_crowd_player.bus = "Master"
	_crowd_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_crowd_player.finished.connect(_on_crowd_finished)
	add_child(_crowd_player)


func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.04) -> void:
	var stream: AudioStream = SOUND_LIBRARY.get(sound_name) as AudioStream
	if stream == null or _voices.is_empty():
		return

	var voice := _take_voice()
	voice.stop()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	voice.play()


func _take_voice() -> AudioStreamPlayer:
	for offset in range(_voices.size()):
		var index := (_next_voice + offset) % _voices.size()
		if not _voices[index].playing:
			_next_voice = (index + 1) % _voices.size()
			return _voices[index]

	# On very busy moments, reuse the oldest voice rather than dropping a key effect.
	var selected := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return selected


func set_crowd_enabled(enabled: bool) -> void:
	_crowd_enabled = enabled
	if not is_instance_valid(_crowd_player):
		return

	if enabled:
		if not _crowd_player.playing:
			_crowd_player.play()
	else:
		_crowd_player.stop()


func _on_crowd_finished() -> void:
	if _crowd_enabled and is_instance_valid(_crowd_player):
		_crowd_player.play()
