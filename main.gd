extends Node


const mix_rate:float = 11025.0

const min_attack_samples:float = 0
const max_attack_samples:float = mix_rate * 2
@export_range (min_attack_samples, max_attack_samples, 1) var attack_samples = min_attack_samples

const min_release_samples:float = 100
const max_release_samples:float = mix_rate * 4
@export_range (min_release_samples, max_release_samples, 1) var release_samples = min_release_samples

const min_decay_samples:float = 0
const max_decay_samples:float = mix_rate * 4
@export_range (min_decay_samples, max_decay_samples, 1) var decay_samples = min_decay_samples

const min_peak_db:float = -80.0
const max_peak_db:float = 0.0
@export_range (min_peak_db, max_peak_db, 1) var peak_db = -20.0

const min_sus_db:float = -80.0
const max_sus_db:float = 0.0
@export_range (min_sus_db, max_sus_db, 1) var sus_db = peak_db


@export var octave_up_btn:Button
@export var octave_down_btn:Button

@export var looping_btn:CheckButton
@export var record_btn:Button
@export var play_btn:Button
@export var stop_btn:Button

@export var save_btn:Button
@export var save_status:Label
var save_dir:String = "user://"

var capture_mix_rate:float = 44100.0  # Default, but will be set dynamically
var capture_play_data: PackedFloat32Array  # Stores interleaved stereo data
var capture_save_data: PackedFloat32Array  # Stores interleaved stereo data
var is_capturing: bool = false

# wave table
@export var wave_table_item_list:ItemList
var wave_table: Dictionary = {
	"sin": func(_phase): return sin(_phase * TAU),
	"triangle": func(_phase): return 1.0 - 4.0 * abs(round(_phase - 0.25) - (_phase - 0.25)),
	"sawtooth": func(_phase): return 2.0 * _phase - 1.0,
	"pulse": func(_phase): return 1.0 if _phase < 0.5 else -1.0
}
var current_waveform = "sin"

# pitch shift
@export var pitch_slider:VSlider
var pitch_slider_center_value = 0.0
var max_pitch_slide_time = 0.5
var pitch_tween:Tween
var scale_tween:Tween

# KNOBS!
@export var peak_knob:Knob
@export var attack_knob:Knob
@export var decay_knob:Knob
@export var sus_knob:Knob
@export var release_knob:Knob

# piano
@export var piano_black:HBoxContainer
@export var piano_white:HBoxContainer

# note label
@export var note_label:Label
var queue_capture:bool = false
var start_recording_text:String = "Start Recording"
var queue_recording_text:String = "Waiting for Key..."
var stop_recording_text:String = "Stop Recording"



# audio player 
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




@onready var capture_play_effect := AudioEffectCapture.new()
@onready var reverb_effect := AudioEffectReverb.new()
@onready var delay_effect := AudioEffectDelay.new()
@onready var capture_save_effect := AudioEffectCapture.new()

@onready var effects:Array = [
	capture_play_effect,
	reverb_effect,
	delay_effect,
	capture_save_effect,
]



	
func _ready() -> void:
	# master / effect bus
	var idx = AudioServer.get_bus_index("Master")
	
	# add effects
	for i in effects.size():
		var effect = effects[i]
		AudioServer.add_bus_effect(idx, effect, i)
		if effect is AudioEffectReverb or effect is AudioEffectDelay:
			AudioServer.set_bus_effect_enabled(idx, i, false)

	# capture settings
	capture_mix_rate = AudioServer.get_mix_rate()  # Dynamically set sample rate for captures
	var output_latency = AudioServer.get_output_latency()
	print("output_latency = %s" % output_latency)
	
	# pitch shift settings
	pitch_slider.value_changed.connect(_on_pitch_slider_value_changed)
	pitch_slider.drag_ended.connect(_on_pitch_slider_drag_ended)
	
	# reverb settings
	pass
	
	# connect signals
	self.looping_btn.toggled.connect(_on_looping_toggled)
	self.record_btn.toggled.connect(_on_record_toggled)
	self.play_btn.toggled.connect(_on_play_toggled)
	self.stop_btn.toggled.connect(_on_stop_toggled)
	self.save_btn.pressed.connect(_on_save_pressed)
	
	# enable / disable btns at start
	play_btn.disabled = true
	save_btn.disabled = true
	stop_btn.disabled = true
	
	
	# octave
	octave_up_btn.pressed.connect(_on_octave_up)
	octave_down_btn.pressed.connect(_on_octave_down)
	
	
	note_label.text = ""
	record_btn.text = start_recording_text
	
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
			piano_btn.current_freq = piano_frequencies[note]
		
		if piano_qwerty.has(note):
			var qwerty_int:Key = piano_qwerty[note] as Key
			var qwerty_key:InputEventKey = InputEventKey.new()
			qwerty_key.keycode = qwerty_int
			piano_btn.qwerty_key = qwerty_key.as_text()
		
		# skip these freqs
		if piano_btn.freq < 261.62 or piano_btn.freq > 1319:
			continue
			
			
		
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
	
	# wave table
	wave_table_item_list.select(0)
	
	
	
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
			var note = piano_qwerty.find_key(event.keycode)
			var freq = piano_frequencies[note]
			
			if event.pressed and pulse_hz != freq:
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note and btn.button_pressed == false:
						btn.pressed.emit(true)
			else:
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note and btn.button_pressed == true:
						btn.button_up.emit()
	



func _on_octave_up() -> void:
	print("up")
	piano_buttons = get_tree().get_nodes_in_group(PIANO_BUTTON_GROUP)
	for btn:PianoButton in piano_buttons:
		btn.freq *= 2.0
		btn.current_freq = btn.freq
		var last_char = btn.note[-1] # Get the last character
		var last_octave = int(last_char) # Convert to integer
		var new_octave = last_octave + 1
		btn.note[-1] = str(new_octave)
		btn.text = "%s\n%s" % [btn.note, btn.qwerty_key]
		if octave_down_btn.disabled:
			octave_down_btn.disabled = false
		if new_octave == 6:
			octave_up_btn.disabled = true

	

func _on_octave_down() -> void:
	print("down")
	piano_buttons = get_tree().get_nodes_in_group(PIANO_BUTTON_GROUP)
	for btn:PianoButton in piano_buttons:
		btn.freq *= 0.5
		btn.current_freq = btn.freq
		var last_char = btn.note[-1] # Get the last character
		var last_octave = int(last_char) # Convert to integer
		var new_octave = last_octave - 1
		btn.note[-1] = str(new_octave)
		btn.text = "%s\n%s" % [btn.note, btn.qwerty_key]
		if octave_up_btn.disabled:
			octave_up_btn.disabled = false
		if new_octave == 1:
			octave_down_btn.disabled = true
	
	
	
func _on_looping_toggled(_toggled_on: bool) -> void:
	if _toggled_on:
		self.loop_mode = AudioStreamWAV.LOOP_FORWARD
		print("set loop enabled")
	else:
		self.loop_mode = AudioStreamWAV.LOOP_DISABLED
		print("set loop disabled")
	_apply_loop_mode()


## Function to apply active effects to the captured audio data
#func apply_active_effects(raw_capture_data:PackedFloat32Array) -> PackedFloat32Array:
	#var processed_data:PackedFloat32Array = []
	#
	## Iterate over the captured audio data and apply effects to each frame
	#for i in range(0, capture_data.size(), 2):  # Process in stereo pairs (left, right)
		#var left_channel = raw_capture_data[i]
		#var right_channel = raw_capture_data[i + 1]
#
		## Apply reverb if it's enabled on bus 2 (Example for reverb)
		#if AudioServer.is_bus_effect_enabled(0, 2):  # Bus 0, Effect 2
			#left_channel = apply_reverb(left_channel)
			#right_channel = apply_reverb(right_channel)
		#
		## Apply delay if it's enabled on bus 3 (Example for delay)
		#if AudioServer.is_bus_effect_enabled(0, 3):  # Bus 0, Effect 3
			#left_channel = apply_delay(left_channel)
			#right_channel = apply_delay(right_channel)
#
		## Add the processed audio back to the processed_data array
		#processed_data.append(left_channel)
		#processed_data.append(right_channel)
#
	## Return processed data
	#return processed_data
#
#
#
## Example function to simulate reverb effect (you would replace this with a real effect)
#func apply_reverb(audio_sample: float) -> float:
	## For the sake of simplicity, we're applying a simple reverb effect as an example
	## A real reverb effect would be more complex and based on audio buffer manipulation
	#return audio_sample * 0.9  # Apply a simple decay to simulate reverb
#
## Example function to simulate delay effect (you would replace this with a real effect)
#func apply_delay(audio_sample: float) -> float:
	## For the sake of simplicity, we're applying a simple delay effect as an example
	## A real delay effect would involve storing past samples and mixing them
	#return audio_sample * 0.8  # Apply a simple delay effect by reducing the sample volume
	
	

func _on_save_pressed() -> void:
	# Return if no data to save
	if capture_save_data.is_empty():
		print("No audio captured!")
		return
	
	# Manually apply any active effects to the captured audio
	print("Applying active effects to captured audio...")
	# var processed_data = apply_active_effects(capture_data)
	
	# Get WAV data
	print("Saving captured audio")
	var capture_wav = convert_to_wav(capture_save_data)
	# var capture_wav = convert_to_wav(processed_data)

	# Disable the save button temporarily
	save_btn.disabled = true
	
	# Check if running on a web build
	if OS.has_feature("web"):
		save_file_web(capture_save_data)
		# save_file_web(processed_data)
	else:
		save_file_native(capture_wav)


# Function for native file save dialog
func save_file_native(capture_wav: AudioStreamWAV) -> void:
	# default name for file
	var file_name = "captured_audio.wav"
	
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.wav ; WAV Audio File"]
	file_dialog.title = "Save Audio File"
	file_dialog.use_native_dialog = true
	# set default file name
	file_dialog.current_path = save_dir + file_name  # Set default directory and file name
	add_child(file_dialog)
	
	# Handle file selection
	file_dialog.file_selected.connect(func(path):
		var error = capture_wav.save_to_wav(path)
		if error == OK:
			save_status.text = "Saved WAV file to: \"%s\"\n(%s)" % [path, ProjectSettings.globalize_path(path)]
		else:
			save_status.text = "Failed to save WAV file!"
		file_dialog.hide()  # Hide the dialog after a file is selected
		# Cleanup after dialog closes
		file_dialog.queue_free()
		# Re-enable save button
		# await get_tree().create_timer(1.0).timeout
		save_btn.disabled = false
	)
	
	# Handle dialog cancellation
	file_dialog.canceled.connect(func():
		save_status.text = "Save canceled!"
		file_dialog.hide()  # Hide the dialog when canceled
		# Cleanup after dialog closes
		file_dialog.queue_free()
		# Re-enable save button
		# await get_tree().create_timer(1.0).timeout
		save_btn.disabled = false
	)
	
	# Show the dialog and wait for it to be closed
	file_dialog.popup_centered()



# Function for web file download
func save_file_web(audio_data: PackedFloat32Array) -> void:
	# default name for file
	var file_name = "captured_audio.wav"
	
	# Convert raw audio data to a proper WAV file format
	var wav_data = convert_audio_to_wav_bytes(audio_data)
	
	if wav_data.is_empty():
		print("Failed to generate WAV data for web download.")
		return
	
	# Encode buffer to Base64 for JavaScript download
	# TODO -- use built in function JavaScriptBridge.download_buffer()
	var base64_str = Marshalls.raw_to_base64(wav_data)
	var js_code = """
		(function() {
			var element = document.createElement('a');
			element.setAttribute('href', 'data:audio/wav;base64,%s');
			element.setAttribute('download', '%s');
			element.style.display = 'none';
			document.body.appendChild(element);
			element.click();
			document.body.removeChild(element);
		})();
	""" % [base64_str, file_name]
	
	await JavaScriptBridge.eval(js_code)
	
	# Re-enable save button
	# await get_tree().create_timer(1.0).timeout
	save_btn.disabled = false
	


func _on_stop_toggled(_toggled_on: bool) -> void:
	print("stop")
	# stop_btn.button_pressed = false
	stop_btn.disabled = true
	
	audio_player.stop()
	
	# play_btn.button_pressed = false
	play_btn.disabled = false
	
	

func _int16_to_bytes(value: int) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	return bytes

func _int32_to_bytes(value: int) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	bytes.append((value >> 16) & 0xFF)
	bytes.append((value >> 24) & 0xFF)
	return bytes
	
	
func create_wav_header(data_size: int, sample_rate: float, channels: int) -> PackedByteArray:
	var header = PackedByteArray()
	var byte_rate = int(sample_rate) * channels * 2  # 16-bit PCM
	
	# RIFF Header
	header.append_array("RIFF".to_utf8_buffer())  # ChunkID
	header.append_array(_int32_to_bytes(36 + data_size))  # ChunkSize
	header.append_array("WAVE".to_utf8_buffer())  # Format
	
	# fmt Subchunk
	header.append_array("fmt ".to_utf8_buffer())  # Subchunk1ID
	header.append_array(_int32_to_bytes(16))  # Subchunk1Size (16 for PCM)
	header.append_array(_int16_to_bytes(1))  # AudioFormat (1 for PCM)
	header.append_array(_int16_to_bytes(channels))  # NumChannels
	header.append_array(_int32_to_bytes(int(sample_rate)))  # SampleRate
	header.append_array(_int32_to_bytes(byte_rate))  # ByteRate
	header.append_array(_int16_to_bytes(channels * 2))  # BlockAlign
	header.append_array(_int16_to_bytes(16))  # BitsPerSample (16-bit)
	
	# data Subchunk
	header.append_array("data".to_utf8_buffer())  # Subchunk2ID
	header.append_array(_int32_to_bytes(data_size))  # Subchunk2Size
	
	return header
	
	
func convert_audio_to_wav_bytes(audio_data: PackedFloat32Array) -> PackedByteArray:
	var pcm_data = PackedByteArray()

	# Convert float (-1.0 to 1.0) to 16-bit PCM (-32768 to 32767)
	for i in range(0, audio_data.size(), 2):  # Process stereo pairs
		var left_sample = int(clamp(audio_data[i] * 32767.0, -32768, 32767))
		var right_sample = int(clamp(audio_data[i + 1] * 32767.0, -32768, 32767))

		# Append left sample (little-endian format)
		pcm_data.append(left_sample & 0xFF)
		pcm_data.append((left_sample >> 8) & 0xFF)

		# Append right sample (little-endian format)
		pcm_data.append(right_sample & 0xFF)
		pcm_data.append((right_sample >> 8) & 0xFF)

	# WAV file header
	var wav_header = create_wav_header(pcm_data.size(), capture_mix_rate, 2)  # Stereo (2 channels)
	
	# Return the full WAV file (header + PCM data)
	return wav_header + pcm_data
	
	
func convert_to_wav(audio_data: PackedFloat32Array) -> AudioStreamWAV:
	var wav_stream = AudioStreamWAV.new()
	
	# Convert from float (-1.0 to 1.0) to 16-bit PCM (-32768 to 32767)
	var pcm_data = PackedByteArray()
	for i in range(0, audio_data.size(), 2):  # Process stereo pairs
		var left_sample = int(clamp(audio_data[i] * 32767.0, -32768, 32767))
		var right_sample = int(clamp(audio_data[i + 1] * 32767.0, -32768, 32767))

		# Append left sample (little-endian format)
		pcm_data.append(left_sample & 0xFF)
		pcm_data.append((left_sample >> 8) & 0xFF)

		# Append right sample (little-endian format)
		pcm_data.append(right_sample & 0xFF)
		pcm_data.append((right_sample >> 8) & 0xFF)

	wav_stream.format = AudioStreamWAV.FORMAT_16_BITS
	wav_stream.mix_rate = capture_mix_rate  # 11025.0  # Match capturing sample rate
	print("mix rate = %s" % capture_mix_rate)
	wav_stream.stereo = true  # Enable stereo playback
	wav_stream.data = pcm_data  # Convert to byte array

	return wav_stream
	
	
	
func _on_play_toggled(_toggled_on: bool) -> void:
	if capture_play_data.is_empty():
		print("No audio captured!")
		return
	
	print("Playing captured audio")
	var capture_wav = convert_to_wav(capture_play_data)
	
	# print("capture_data: %s" % capture_data)
	print("capture_wav.format: %s" % capture_wav.format)
	print("capture_wav.mix_rate: %s" % capture_wav.mix_rate)
	print("capture_wav.stereo: %s" % capture_wav.stereo)
	var _data = capture_wav.get_data()
	print("data.size(): %s" % _data.size())
		
	audio_player.stream = capture_wav

	# enable/disable btn
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
	play_btn.disabled = false
	stop_btn.disabled = true
	
func _on_loop() -> void:
	print("loop")
	audio_player.play()
	var test = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	print("test = %s" % test)
	


func _process(_delta):
	if is_capturing:
		# playback data (no effects applied)
		var available_play_frames = capture_play_effect.get_frames_available()
		if available_play_frames > 0:
			var play_buffer = capture_play_effect.get_buffer(available_play_frames)  # Get only the required frames
			for frame in play_buffer:
				capture_play_data.append(frame.x)  # Left channel
				capture_play_data.append(frame.y)  # Right channel
		# save data (all effects applied)
		var available_save_frames = capture_save_effect.get_frames_available()
		if available_save_frames > 0:
			var save_buffer = capture_save_effect.get_buffer(available_save_frames)  # Get only the required frames
			for frame in save_buffer:
				capture_save_data.append(frame.x)  # Left channel
				capture_save_data.append(frame.y)  # Right channel




func start_capturing():
	# clear buffer
	capture_play_effect.clear_buffer()
	capture_play_data.clear()
	capture_save_effect.clear_buffer()
	capture_save_data.clear()
	
	print("Start Capturing")
	is_capturing = true

	record_btn.text = stop_recording_text
	play_btn.disabled = true
	save_btn.disabled = true
	

func stop_capturing():
	print("Stop Capturing")
	is_capturing = false

	record_btn.text = start_recording_text
	play_btn.disabled = false  # Enable play button after capturing stops
	save_btn.disabled = false
	
	
	
func _on_record_toggled(_toggled_on: bool) -> void:
	if _toggled_on:
		queue_capture = true
		record_btn.text = queue_recording_text
		# start_capturing()
	else:
		if queue_capture:
			queue_capture = false
			record_btn.text = start_recording_text
		else:
			stop_capturing()
	
	
func _on_piano_button_pressed(btn:PianoButton) -> void:
	print("hello")
	note_label.text = btn.text
	# start capture if queued
	if queue_capture:
		queue_capture = false
		start_capturing()
	
	
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


# assign qwerty key to each piano note
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


func _on_pitch_slider_value_changed(value: float) -> void:
	# print("value changed: %s" % value)
	var target_scale = remap(value, -1.0, 1.0, 1.0 - 0.059*2.0, 1.0 + 0.059*2.0)
	for btn:PianoButton in piano_buttons:
		btn.queue_pitch_change(target_scale)
				

func _on_pitch_slider_drag_ended(_value_changed: bool) -> void:
	# Return slider to zero smoothly
	var distance_from_center = abs(pitch_slider.value)
	if pitch_tween:
		pitch_tween.kill()
	pitch_tween = create_tween()
	pitch_tween.set_ease(Tween.EASE_OUT)
	pitch_tween.set_trans(Tween.TRANS_SINE)
	pitch_tween.tween_property(pitch_slider, "value", pitch_slider_center_value, max_pitch_slide_time * distance_from_center)


func _on_wave_table_item_selected(idx: int) -> void:
	print(idx)
	var wave_keys = wave_table.keys()
	# print(wave_keys)
	if idx >= 0 and idx < wave_keys.size():
		current_waveform = wave_keys[idx]
		print("Current waveform set to: ", current_waveform)
		for btn:PianoButton in piano_buttons:
			btn.queue_waveform_change(idx)


func _on_sweep_toggled(toggled_on: bool) -> void:
	if toggled_on:
		for btn:PianoButton in piano_buttons:
			btn.start_waveform_tween()
	else:
		for btn:PianoButton in piano_buttons:
			btn.stop_waveform_tween()
		


func _on_blend_toggled(toggled_on: bool) -> void:
	if toggled_on:
		for btn:PianoButton in piano_buttons:
			btn.blend = true
	else:
		for btn:PianoButton in piano_buttons:
			btn.blend = false


func _on_radius_value_changed(value: float) -> void:
	for btn:PianoButton in piano_buttons:
		btn.radius = value


func _on_reverb_toggled(toggled_on: bool) -> void:
	var reverb_index = effects.find(reverb_effect)
	if toggled_on:
		AudioServer.set_bus_effect_enabled(0, reverb_index, true)
	else:
		AudioServer.set_bus_effect_enabled(0, reverb_index, false)
		


func _on_delay_toggled(toggled_on: bool) -> void:
	var delay_index = effects.find(delay_effect)
	if toggled_on:
		AudioServer.set_bus_effect_enabled(0, delay_index, true)
	else:
		AudioServer.set_bus_effect_enabled(0, delay_index, false)
