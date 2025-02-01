extends Node

const mix_rate:float = 11025.0

const min_attack_samples:float = 0
const max_attack_samples:float = mix_rate * 2
@export_range (min_attack_samples, max_attack_samples, 1) var attack_samples = 0

const min_release_samples:float = 100
const max_release_samples:float = mix_rate * 4
@export_range (min_release_samples, max_release_samples, 1) var release_samples = 100

const min_decay_samples:float = 0
const max_decay_samples:float = mix_rate * 4
@export_range (min_decay_samples, max_decay_samples, 1) var decay_samples = 0

const min_peak_db:float = -80.0
const max_peak_db:float = 0.0
@export_range (min_peak_db, max_peak_db, 1) var peak_db = -20.0

const min_sus_db:float = -80.0
const max_sus_db:float = 0.0
@export_range (min_sus_db, max_sus_db, 1) var sus_db = peak_db



@export var looping_btn:CheckButton
@export var record_btn:Button
@export var play_btn:Button
@export var stop_btn:Button

@export var save_btn:Button
@export var save_status:Label
var save_dir:String = "user://"

var record_test = "Record"
var stop_text = "Stop"
var effect:AudioEffectRecord
var recording:AudioStreamWAV


# KNOBS!
@export var peak_knob:Knob
@export var attack_knob:Knob
@export var decay_knob:Knob
@export var sus_knob:Knob
@export var release_knob:Knob


@export var down:Button
@export var current:Button
@export var up:Button

@export var piano_black:HBoxContainer
@export var piano_white:HBoxContainer

@export var note_label:Label




@export var polyphonic_player:AudioStreamPlayer
@export var audio_player:AudioStreamPlayer

var loop_mode:AudioStreamWAV.LoopMode = AudioStreamWAV.LOOP_DISABLED
var playback # Will hold the AudioStreamGeneratorPlayback.
@onready var sample_hz = audio_player.stream.mix_rate
var pulse_hz = -1.0 # The frequency of the sound wave.

var white_keys = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]
var black_keys = [KEY_2, KEY_3, KEY_5, KEY_6, KEY_7, KEY_9, KEY_0, KEY_S, KEY_D, KEY_F, KEY_H, KEY_J]
var note_names = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]

@onready var piano_frequencies:Dictionary = generate_piano_frequencies()  # keys are note names like A4, values are freqs like 440.0
@onready var piano_qwerty:Dictionary = generate_piano_qwerty()  # keys are note names like A4, values are InputEventKey such as KEY_Y
@onready var keys_to_map:Array = piano_qwerty.values()

@onready var keys:Array = piano_frequencies.keys()
@onready var index:int = 30

# var piano_button_group:ButtonGroup = PianoButton.PIANO_BUTTON_GROUP
const PIANO_BUTTON_GROUP = "piano_button"
var piano_buttons:Array





	
func _ready() -> void:
	# record button
	# We get the index of the "Record" bus.
	var idx = AudioServer.get_bus_index("Master")
	# And use it to retrieve its first effect, which has been defined
	# as an "AudioEffectRecord" resource.
	effect = AudioServer.get_bus_effect(idx, 0)
	
	# connect signals
	self.looping_btn.toggled.connect(_on_looping_toggled)
	record_btn.text = record_test
	self.record_btn.toggled.connect(_on_record_toggled)
	self.play_btn.toggled.connect(_on_play_toggled)
	self.stop_btn.toggled.connect(_on_stop_toggled)
	# enable / disable
	if not recording:
		play_btn.disabled = true
		save_btn.disabled = true
		stop_btn.disabled = true
	self.save_btn.pressed.connect(_on_save_pressed)

	
	
	note_label.text = ""
	
	print(piano_frequencies)
	print()
	print(piano_qwerty)
	
	
	for note in keys:
		
		var piano_btn:PianoButton = PianoButton.new()
		# set vars
		piano_btn.note = note
		piano_btn.mix_rate = self.mix_rate
		
		piano_btn.attack_samples = self.attack_samples
		piano_btn.release_samples = self.release_samples
		piano_btn.peak_db = self.peak_db
		piano_btn.sus_db = self.sus_db
		piano_btn.decay_samples = self.decay_samples
		
		
		if piano_frequencies.has(note):
			piano_btn.freq = piano_frequencies[note]
		
		if piano_qwerty.has(note):
			var qwerty_int:Key = piano_qwerty[note] as Key
			var qwerty_key:InputEventKey = InputEventKey.new()
			qwerty_key.keycode = qwerty_int
			piano_btn.qwerty_key = qwerty_key.as_text()
		
		if piano_btn.freq < 261.62 or piano_btn.freq > 1319:
			pass
		else:
			# connect signals
			piano_btn.piano_button_pressed.connect(_on_piano_button_pressed)
			
			# add child
			if piano_btn.note.contains("#"):
				if piano_btn.note == "C#3":
					var spacer = Label.new()
					spacer.custom_minimum_size.x = 64.0 / 2.0
					spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					piano_black.add_child(spacer)
				elif piano_btn.note.contains("F"):
					# piano_btn.note == "F#3":
					var spacer = Label.new()
					spacer.custom_minimum_size.x = 64.0
					spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					piano_black.add_child(spacer)
				elif piano_btn.note.contains("C"):
					# piano_btn.note == "C#4":
					var spacer = Label.new()
					spacer.custom_minimum_size.x = 64.0
					spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
					piano_black.add_child(spacer)
					
				
				piano_btn.is_black = true
				# piano_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
				piano_black.add_child(piano_btn)
			else:
				piano_white.add_child(piano_btn)
				
	
	# test
	piano_buttons = get_tree().get_nodes_in_group(PIANO_BUTTON_GROUP)
	print("piano_buttons")
	print(piano_buttons)
	
	# turn knobs
	
	# peak db knob
	# set initial rotation of knob
	var peak_init = remap(peak_db, min_peak_db, max_peak_db, 18.1690, 81.8309)
	print("peak_init = %s" % peak_init)
	var peak_fang:float = lerp_angle(peak_knob.knob.rotation, peak_init, 0.3)
	print("peak_fang = %s" % peak_fang)
	peak_knob.knob.rotation = remap(peak_db, min_peak_db, max_peak_db, -2, 2)
	print("peak_rot = %s" % peak_knob.knob.rotation)
	# signal to update btns
	peak_knob.turned.connect(_on_knob_turned.bind("P"))
	peak_knob.turned.emit(peak_init)
	
	
	# attack knob
	# set initial rotation of knob
	var attack_init = remap(attack_samples, min_attack_samples, max_attack_samples, 18.1690, 81.8309)
	print("attack_init = %s" % attack_init)
	var attack_fang:float = lerp_angle(attack_knob.knob.rotation, attack_init, 0.3)
	print("attack_fang = %s" % attack_fang)
	attack_knob.knob.rotation = remap(attack_samples, min_attack_samples, max_attack_samples, -2, 2)
	print("attack_rot = %s" % attack_knob.knob.rotation)
	# signal to update btns
	attack_knob.turned.connect(_on_knob_turned.bind("A"))
	attack_knob.turned.emit(attack_init)
	
	# decay knob
	# set initial rotation of knob
	var decay_init = remap(decay_samples, min_decay_samples, max_decay_samples, 18.1690, 81.8309)
	print("decay_init = %s" % decay_init)
	var decay_fang:float = lerp_angle(decay_knob.knob.rotation, decay_init, 0.3)
	print("decay_fang = %s" % decay_fang)
	decay_knob.knob.rotation = remap(decay_samples, min_decay_samples, max_decay_samples, -2, 2)
	print("decay_rot = %s" % decay_knob.knob.rotation)
	# signal to update btns
	decay_knob.turned.connect(_on_knob_turned.bind("D"))
	decay_knob.turned.emit(decay_init)
	
	# sus knob
	# set initial rotation of knob
	var sus_init = remap(sus_db, min_sus_db, max_sus_db, 18.1690, 81.8309)
	print("sus_init = %s" % sus_init)
	var sus_fang:float = lerp_angle(sus_knob.knob.rotation, sus_init, 0.3)
	print("sus_fang = %s" % sus_fang)
	sus_knob.knob.rotation = remap(sus_db, min_sus_db, max_sus_db, -2, 2)
	print("sus_rot = %s" % sus_knob.knob.rotation)
	# signal to update btns
	sus_knob.turned.connect(_on_knob_turned.bind("S"))
	sus_knob.turned.emit(sus_init)
	
	# release knob
	# set initial rotation of knob
	var release_init = remap(release_samples, min_release_samples, max_release_samples, 18.1690, 81.8309)
	print("release_init = %s" % release_init)
	var release_fang:float = lerp_angle(release_knob.knob.rotation, release_init, 0.3)
	print("release_fang = %s" % release_fang)
	release_knob.knob.rotation = remap(release_samples, min_release_samples, max_release_samples, -2, 2)
	print("release_rot = %s" % release_knob.knob.rotation)
	# signal to update btns
	release_knob.turned.connect(_on_knob_turned.bind("R"))
	release_knob.turned.emit(release_init)
	


func _input(_event) -> void:
	# process quit / restart
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	
	# process key events
	process_event(_event)


# process piano key events
func process_event(event) -> void:
	if event is InputEventKey:
		if white_keys.has(event.keycode) or black_keys.has(event.keycode):
			# print(event.as_text())
			var note = piano_qwerty.find_key(event.keycode)
			# print(note)
			var freq = piano_frequencies[note]
			# print(freq)
			
			if event.pressed and pulse_hz != freq:
				# play_freq(freq)
				# note_label.text = note
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note and btn.button_pressed == false:
						# btn.button_pressed = true
						# btn.toggled.emit(true)
						btn.pressed.emit()
			else:
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note and btn.button_pressed == true:
						# btn.button_pressed = false
						# btn.toggled.emit(false)
						btn.button_up.emit()
	



func _on_looping_toggled(_toggled_on: bool) -> void:
	if _toggled_on:
		self.loop_mode = AudioStreamWAV.LOOP_FORWARD
		print("set loop enabled")
	else:
		self.loop_mode = AudioStreamWAV.LOOP_DISABLED
		print("set loop disabled")
	_apply_loop_mode()



func _on_save_pressed() -> void:
	if recording:
		save_btn.disabled = true
		var save_path = save_dir + "test.wav"
		recording.save_to_wav(save_path)
		save_status.text = "Saved WAV file to: \"%s\"\n(%s)" % [save_path, ProjectSettings.globalize_path(save_path)]
		await get_tree().create_timer(1.0).timeout
		print("WAIWDOIAJSDASDASDASD")
		save_btn.disabled = false
	
	


func _on_stop_toggled(_toggled_on: bool) -> void:
	print("stop")
	# stop_btn.button_pressed = false
	stop_btn.disabled = true
	
	audio_player.stop()
	
	# play_btn.button_pressed = false
	play_btn.disabled = false
	
	


func _on_play_toggled(_toggled_on: bool) -> void:
	if recording:

		print("recording: %s" % recording)
		print("recording.format: %s" % recording.format)
		print("recording.mix_rate: %s" % recording.mix_rate)
		print("recording.stereo: %s" % recording.stereo)
		var _data = recording.get_data()
		print("data.size(): %s" % _data.size())
		
		# set stream
		audio_player.stream = recording
		
		# enable/disable btn
		# if recording.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# disable playback until complete
		play_btn.disabled = true
		stop_btn.disabled = false
		
		# apply loop mode
		_apply_loop_mode()
		
		# play
		audio_player.play()

	

func _apply_loop_mode() -> void:
	# no looping
	if self.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		if audio_player.finished.is_connected(_on_loop):
			audio_player.finished.disconnect(_on_loop)
		if audio_player.finished.is_connected(_on_finished):
			audio_player.finished.disconnect(_on_finished)
		audio_player.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	
	# looping
	if self.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		if audio_player.finished.is_connected(_on_loop):
			audio_player.finished.disconnect(_on_loop)
		audio_player.finished.connect(_on_loop, CONNECT_PERSIST)
			
			
func _on_finished() -> void:
	print("done") 
	# play_btn.button_pressed = false
	# stop_btn.button_pressed = false
	play_btn.disabled = false
	stop_btn.disabled = true
	
func _on_loop() -> void:
	print("loop")
	#audio_player.volume_db = -20  # Fade out to reduce pop noise
	#audio_player.seek(0.0)  # Reset to the start without stopping
	#await get_tree().create_timer(0.05).timeout  # Small delay
	#audio_player.volume_db = 0  # Restore volume
	# await get_tree().process_frame
	audio_player.play()
	var test = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	print("test = %s" % test)
	

#func _process(_delta: float) -> void:
	#if audio_player.playing and self.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		#var len = audio_player.stream.get_length()
		#var play_pos = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
		#print("play_pos = %s" % play_pos)
		#print("len = %s" % len)


	
func _on_record_toggled(_toggled_on: bool) -> void:
	if effect.is_recording_active():
		# stop recording
		
		record_btn.text = record_test
		recording = effect.get_recording()
		effect.set_recording_active(false)
		
		play_btn.disabled = false
		save_btn.disabled = false
		# stop_btn.disabled = true
		
		# $RecordButton.text = "Record"
		# $Status.text = ""
	else:
		# start recording
		record_btn.text = stop_text
		effect.set_recording_active(true)
		
		play_btn.disabled = true
		save_btn.disabled = true
		# stop_btn.disabled = false
		
		# $RecordButton.text = "Stop"
		# $Status.text = "Recording..."


func _on_piano_button_pressed(btn:PianoButton) -> void:
	print("hello")
	note_label.text = btn.text
	
	
func _on_knob_turned(deg:float, type:String="") -> void:
	match type:
		"P":
			var clamped_deg = clamp(deg, 18.1690, 81.8309)
			var value = remap(clamped_deg, 18.1690, 81.8309, min_peak_db, max_peak_db)
			print("P knob: %s" % value)
			self.peak_db = value
			for btn:PianoButton in piano_buttons:
				btn.peak_db = self.peak_db
			
		"A":
			var clamped_deg = clamp(deg, 18.1690, 81.8309)
			var value = remap(clamped_deg, 18.1690, 81.8309, min_attack_samples, max_attack_samples)
			print("A knob: %s" % value)
			self.attack_samples = value
			for btn:PianoButton in piano_buttons:
				btn.attack_samples = self.attack_samples
				
		
		"D":
			var clamped_deg = clamp(deg, 18.1690, 81.8309)
			var value = remap(clamped_deg, 18.1690, 81.8309, min_decay_samples, max_decay_samples)
			print("D knob: %s" % value)
			self.decay_samples = value
			for btn:PianoButton in piano_buttons:
				btn.decay_samples = self.decay_samples
		
		"S":
			var clamped_deg = clamp(deg, 18.1690, 81.8309)
			var value = remap(clamped_deg, 18.1690, 81.8309, min_sus_db, max_sus_db)
			print("S knob: %s" % value)
			self.sus_db = value
			for btn:PianoButton in piano_buttons:
				btn.sus_db = self.sus_db
				
				
		"R":
			var clamped_deg = clamp(deg, 18.1690, 81.8309)
			var value = remap(clamped_deg, 18.1690, 81.8309, min_release_samples, max_release_samples)
			print("R knob: %s" % value)
			self.release_samples = value
			for btn:PianoButton in piano_buttons:
				btn.release_samples = self.release_samples
			
			pass
		_:
			push_warning("'%s' type not matched" % type)
	pass
	
	
	
# func _on_piano_key_toggled(_toggled_on:bool, _btn:PianoButton) -> void:
	# pass
	# update button pressed
	# btn.button_pressed = toggled_on
	
	#if toggled_on:
		#var freq = btn.freq
		#if pulse_hz != freq:
			#print("NEW FREQ")
			#play_freq(freq)
			#note_label.text = btn.note
		## play_freq(freq)
	#else:
		#var freq = btn.freq
		#if pulse_hz == freq:
			#print("STOP FREQ")
			#stop_freq()
			#note_label.text = btn.note



# play note and reset index to new note
func play_note(new_index:int = 0, save:bool = true) -> void:
	# update index and clamp to keys array size
	var temp = clamp(new_index, 0, keys.size()-1)
	# update index
	if save:
		index = temp
	
	# get note name to play
	var note = keys[temp]
	print(note)
	
	# get freq to play
	var freq = piano_frequencies[note]
	# play frequency
	play_freq(freq)


func play_freq(freq:float = 440.0) -> void:
	# get frequency to play
	pulse_hz = freq
	
	# play the frequency
	audio_player.play()
	playback = audio_player.get_stream_playback()
	fill_buffer()


func stop_freq() -> void:
	audio_player.stop()
	pulse_hz = -1.0  # reset freq



func fill_buffer():
	var phase:float = 0.0
	var increment = pulse_hz / sample_hz
	var frames_available = playback.get_frames_available()

	for i in range(frames_available):
		var waveform:float
		
		# sine waveform
		var _sin = sin(phase * TAU)
		
		# sawtooth waveform
		var _sawtooth = 2.0 * phase - 1.0  # Convert phase [0,1] to sawtooth [-1,1]

		# choose waveform
		waveform = _sin
		# waveform = _sawtooth
		
		# push waveform and update phase
		playback.push_frame(Vector2.ONE * waveform)
		phase = fmod(phase + increment, 1.0)
		





func generate_piano_frequencies() -> Dictionary:
	var frequencies = {}
	var base_note = 27.5  # Frequency of A0

	var key_number = 1  # Start with A0
	for octave in range(0, 8):
		for note in note_names:
			
			if octave == 7 and note == "C":
				frequencies["C8"] = 4186.01
				break

			frequencies["%s%d" % [note, octave]] = base_note * pow(2, (key_number - 1) / 12.0)
			key_number += 1

	return frequencies


func generate_piano_qwerty() -> Dictionary:
	var result = {}

	var white_key_index = 0
	var black_key_index = 0

	for octave in range(0, 8):
		for note in note_names:
			var key_name = "%s%d" % [note, octave]
			
			if octave < 3:  # Skip notes before C3
				continue
			elif octave == 3:
				if ["A", "A#", "B"].has(note):
					continue
			
			if note.contains("#"):
				if black_key_index < black_keys.size():
					result[key_name] = black_keys[black_key_index]
					black_key_index += 1
			else:
				if white_key_index < white_keys.size():
					result[key_name] = white_keys[white_key_index]
					white_key_index += 1

	return result
	
	
func _on_down_pressed() -> void:
	play_note(index - 1, true)


func _on_current_pressed() -> void:
	play_note(index, true)


func _on_up_pressed() -> void:
	play_note(index + 1, true)
