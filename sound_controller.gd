extends RefCounted

const MIX_RATE := 22050.0

var host: Node
var sfx_player: AudioStreamPlayer

func setup(host_node: Node):
	host = host_node
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.2
	sfx_player.stream = stream
	host.add_child(sfx_player)

func play_cue(cue_name: String):
	match cue_name:
		"hack":
			_play_tone_sequence([[660.0, 0.08, 0.22], [880.0, 0.12, 0.22]])
		"locked":
			_play_tone_sequence([[220.0, 0.08, 0.22], [180.0, 0.1, 0.22]])
		"guard_alert", "camera_alert", "failure":
			_play_tone_sequence([[880.0, 0.08, 0.24], [880.0, 0.08, 0.24], [660.0, 0.12, 0.24]])
		"switch":
			_play_tone_sequence([[520.0, 0.07, 0.18], [720.0, 0.08, 0.18]])
		"elevator", "transition":
			_play_tone_sequence([[380.0, 0.05, 0.16], [520.0, 0.08, 0.16]])
		"success":
			_play_tone_sequence([[523.0, 0.09, 0.2], [659.0, 0.09, 0.2], [784.0, 0.14, 0.2]])
		"pause":
			_play_tone_sequence([[420.0, 0.08, 0.14]])
		"resume":
			_play_tone_sequence([[620.0, 0.08, 0.14]])

func _play_tone_sequence(notes: Array):
	if sfx_player == null:
		return

	sfx_player.stop()
	sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = sfx_player.get_stream_playback()
	if playback == null:
		return

	var frames := PackedVector2Array()
	for note in notes:
		var frequency: float = note[0]
		var duration: float = note[1]
		var amplitude: float = note[2]
		var frame_count := int(MIX_RATE * duration)
		for frame_index in range(frame_count):
			var phase = TAU * frequency * float(frame_index) / MIX_RATE
			var sample = sin(phase) * amplitude
			frames.append(Vector2(sample, sample))

	playback.clear_buffer()
	playback.push_buffer(frames)
