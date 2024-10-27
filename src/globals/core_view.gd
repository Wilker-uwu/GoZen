extends Node


signal _on_current_frame_changed(frame: int)
signal _update_frame_forced

signal _playback_paused
signal _playback_started



var is_playing: bool = false

var current_frame: int = 0
var prev_frame: int = -1
var _skipped_frames: int = 0

var time_elapsed: float = 0.

var frames: Array[Texture2D] = []

var current_clips: Array[ClipData] = []
var audio_players: Array[AudioStreamPlayer] = []



func _ready() -> void:
	CoreError.err_connect([
			CoreTimeline._on_track_added.connect(_on_track_added),
			CoreTimeline._on_track_removed.connect(_on_track_removed),
			Project._on_project_loaded.connect(_on_project_loaded)])


func _process(a_delta: float) -> void:
	if is_playing:
		time_elapsed += a_delta

		if time_elapsed < 1. / Project.framerate:
			return

		while time_elapsed >= 1. / Project.framerate:
			time_elapsed -= 1. / Project.framerate
			current_frame += 1
			_skipped_frames += 1
		
		if current_frame >= Project._end_pts:
			is_playing = false
			_playback_paused.emit()
		else:
			while _skipped_frames != 1:
				next_frame(true)
				_skipped_frames -= 1

			next_frame(false)


func _on_project_loaded() -> void:
	CoreError.err_resize([
			frames.resize(Project.tracks.size()),
			audio_players.resize(Project.tracks.size()),
			current_clips.resize(Project.tracks.size())])

	for l_track_id: int in Project.tracks.size():
		audio_players[l_track_id] = AudioStreamPlayer.new()


func _on_track_added() -> void:
	frames.append(null)
	audio_players.append(AudioStreamPlayer.new())	
	add_child(audio_players[-1])
	current_clips.append(null)


func _on_track_removed(a_id: int) -> void:
	frames.remove_at(a_id)
	audio_players[a_id].queue_free()
	audio_players.remove_at(a_id)
	current_clips.remove_at(a_id)
	

func _on_play_pressed() -> void:
	# Don't play past end frame
	if current_frame >= Project._end_pts:
		return

	is_playing = !is_playing

	if is_playing:
		_playback_started.emit()
	else:
		for l_player: AudioStreamPlayer in audio_players:
			l_player.set_stream_paused(true)

		_playback_paused.emit()

	time_elapsed = 0.


func next_frame(a_skip_signal: bool) -> void:
	if !a_skip_signal:
		_on_current_frame_changed.emit(current_frame)	
		_set_frame()


func _set_frame(a_frame_nr: int = current_frame, a_force: bool = false) -> void:
	if prev_frame == a_frame_nr and !a_force:
		return
	
	prev_frame = current_frame

	for i: int in Project.tracks.size():
		# Check if clip expired
		if current_clips[i] != null and (!current_clips[i].current_check(current_frame) or current_clips[i].track_id != i):
			frames[i] = null
			audio_players[i].stream = null
			current_clips[i] = null

		# Check if clip is loaded
		if current_clips[i] == null: # Find which clip is there
			current_clips[i] = _get_clip_from_raw(i)
			audio_players[i].stream = null

		# Set the current frame data
		if current_clips[i] != null:
			match Project.files[current_clips[i].file_id].type:
				File.VIDEO: _set_video_clip_frame(i)
				File.AUDIO: _set_audio_clip_frame(i)
				File.IMAGE: _set_image_clip_frame(i)
				File.COLOR: _set_color_clip_frame(i)
		else:
			frames[i] = null
			audio_players[i].stream = null
			current_clips[i] = null

	
func _get_clip_from_raw(a_track_id: int) -> ClipData:
	if current_frame in Project.tracks[a_track_id].keys():
		return Project.clips[Project.tracks[a_track_id][current_frame]]
	elif Project.tracks[a_track_id].size() != 0 and current_frame < Project.tracks[a_track_id].keys().min():
		return null

	for i: int in current_frame + 1:
		if current_frame - i in Project.tracks[a_track_id].keys():
			var l_clip_data: ClipData = Project.clips[Project.tracks[a_track_id][current_frame - i]]

			if current_frame < l_clip_data.get_end_pts():
				return l_clip_data
	return null
	

func _set_video_clip_frame(a_track_id: int, a_frame_nr: int = current_frame) -> void:
	var l_video: VideoData = Project._files_data[current_clips[a_track_id].file_id][a_track_id]

	if l_video.next_available(a_frame_nr, current_clips[a_track_id]):
		frames[a_track_id] = l_video.get_frame()

	_set_audio_clip_frame(a_track_id, true)


func _set_audio_clip_frame(a_track_id: int, a_video: bool = false, a_frame_nr: int = current_frame) -> void:
	# Setting audio stream if needed
	print(Time.get_time_string_from_system())

	if audio_players[a_track_id].stream == null:
		if a_video:
			var l_video: VideoData = Project._files_data[current_clips[a_track_id].file_id][0]
			audio_players[a_track_id].stream = l_video.audio_data
		else:
			audio_players[a_track_id].stream = Project._files_data[current_clips[a_track_id].file_id]

	a_frame_nr -= current_clips[a_track_id].pts - current_clips[a_track_id].start

	if is_playing and !audio_players[a_track_id].playing:
		print("Stream starts playing")
		audio_players[a_track_id].play((a_frame_nr as float / Project.framerate) - (1. / Project.framerate))
	elif !is_playing:
		print("Stream is starts playing from nothing")
		audio_players[a_track_id].set_stream_paused(false) # Seeking doesn't work if stream is paused
		audio_players[a_track_id].seek((a_frame_nr as float / Project.framerate) - (1. / Project.framerate))

	audio_players[a_track_id].set_stream_paused(!is_playing)


func _set_image_clip_frame(a_track_id: int) -> void:
	frames[a_track_id] = Project._files_data[current_clips[a_track_id].file_id]


func _set_color_clip_frame(a_track_id: int) -> void:
	frames[a_track_id] = Project._files_data[current_clips[a_track_id].file_id]


func update_frame_forced() -> void:
	_update_frame_forced.emit()

