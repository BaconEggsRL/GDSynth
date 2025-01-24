extends Node



@export var down:Button
@export var current:Button
@export var up:Button

@export var piano_black:HBoxContainer
@export var piano_white:HBoxContainer

@export var note_label:Label




@export var audio_player:AudioStreamPlayer

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

var piano_button_group:ButtonGroup = PianoButton.PIANO_BUTTON_GROUP
var piano_buttons:Array


func _ready() -> void:
	note_label.text = ""
	
	print(piano_frequencies)
	print()
	print(piano_qwerty)
	
	
	for note in keys:
		
		var piano_btn:PianoButton = PianoButton.new()
		# set vars
		piano_btn.note = note
		
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
			# connect toggled
			piano_btn.toggled.connect(_on_piano_key_toggled.bind(piano_btn))
			
			# add child
			if piano_btn.note.contains("#"):
				if piano_btn.note == "C#3":
					var spacer = Label.new()
					spacer.custom_minimum_size.x = 64.0 / 2.0
					piano_black.add_child(spacer)
				elif piano_btn.note.contains("F"):
					# piano_btn.note == "F#3":
					var spacer = Label.new()
					spacer.custom_minimum_size.x = 64.0
					piano_black.add_child(spacer)
				elif piano_btn.note.contains("C"):
					# piano_btn.note == "C#4":
					var spacer = Label.new()
					spacer.custom_minimum_size.x = 64.0
					piano_black.add_child(spacer)
					
				
				piano_btn.is_black = true
				piano_black.add_child(piano_btn)
			else:
				piano_white.add_child(piano_btn)
				
	
	# test
	piano_buttons = piano_button_group.get_buttons()
	print("piano_buttons")
	print(piano_buttons)


func _input(event) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		
	if event is InputEventKey:
		if white_keys.has(event.keycode):
			print("event")
			# print(event.as_text())
			var note = piano_qwerty.find_key(event.keycode)
			# print(note)
			var freq = piano_frequencies[note]
			# print(freq)
			
			if event.pressed and pulse_hz != freq:
				play_freq(freq)
				note_label.text = note
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note:
						# btn.button_pressed = true
						btn.toggled.emit(true)
			else:
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note:
						# btn.button_pressed = true
						btn.toggled.emit(false)
					
			
		elif black_keys.has(event.keycode):
			print(event.as_text())
			var note = piano_qwerty.find_key(event.keycode)
			print(note)
			var freq = piano_frequencies[note]
			print(freq)
			
			if event.pressed and pulse_hz != freq:
				play_freq(freq)
				note_label.text = note
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note:
						# btn.button_pressed = true
						btn.toggled.emit(true)
			else:
				# update piano button toggled
				for btn:PianoButton in piano_buttons:
					if btn.name == note:
						# btn.button_pressed = true
						btn.toggled.emit(false)
		



func _on_piano_key_toggled(toggled_on:bool, btn:PianoButton) -> void:
	# update button pressed
	btn.button_pressed = toggled_on
	
	if toggled_on:
		var freq = btn.freq
		if pulse_hz != freq:
			print("NEW FREQ")
			play_freq(freq)
			note_label.text = btn.note
		# play_freq(freq)
	else:
		var freq = btn.freq
		if pulse_hz == freq:
			print("STOP FREQ")
			stop_freq()
			note_label.text = btn.note



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
	var phase = 0.0
	var increment = pulse_hz / sample_hz
	var frames_available = playback.get_frames_available()

	for i in range(frames_available):
		playback.push_frame(Vector2.ONE * sin(phase * TAU))
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
