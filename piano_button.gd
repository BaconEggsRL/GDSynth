class_name PianoButton
extends Button

# attack max amplitude
var peak_db = 0.0
# decay time
var decay_samples:float = 0.0
# sustain amplitude
var sus_db = -10.0


@export var qwerty_key:String = "Y"

@export var note:String = "A4"
@export var freq:float = -1.0

@export var is_black:bool = false

@export var min_x:float = 64.0
@export var min_y:float = 200.0


var mix_rate:float = 11025.0
var release_samples = mix_rate
var attack_samples = mix_rate
@export var buffer_length:float = 0.5

var volume_tweener:Tween
@onready var audio_player:AudioStreamPlayer = self.create_audio_player()
@onready var playback:AudioStreamPlayback
@onready var sample_hz:float = audio_player.stream.mix_rate

# for continuous press
var phase: float = 0.0
# for waveform modulation
var LFO_phase: float = 0.0
var LFO_rate: float = 0.01  # Adjust speed of LFO modulation

var is_hovering:bool = false
const PIANO_BUTTON_GROUP = "piano_button"

signal piano_button_pressed


# multi-touch for mobile
var active_touches: Dictionary = {}
var tween_time: float = 2.0

# var to track whether pressed by qwerty or mouse
var qwerty:bool = false



# wave table
var wave_table: Dictionary = {
	"sin": func(_phase): return sin(_phase * TAU),
	# "triangle": func(_phase): return 1.0 - 4.0 * abs(round(_phase - 0.25) - (_phase - 0.25)),
	# "sawtooth": func(_phase): return 2.0 * _phase - 1.0,
	# "pulse": func(_phase): return 1.0 if _phase < 0.5 else -1.0
}
var current_waveform = "sin"
var waveform_index: float = 0.0
var waveform_target_index: float = 0.0
var tween:Tween


	
	
func create_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = mix_rate
	stream.buffer_length = buffer_length
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # required for web build
	
	self.add_child(player)
	return player


func _start_waveform_tween(target_index:int = wave_table.keys().size() - 1):
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "waveform_index", target_index, tween_time)
	tween.finished.connect(_restart_waveform_tween)
	tween.play()


func _restart_waveform_tween(target_index:int = 0):
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "waveform_index", target_index, tween_time)
	tween.finished.connect(_start_waveform_tween)
	tween.play()
	
	
	
func _ready() -> void:
	# waveform tweener
	_start_waveform_tween(wave_table.keys().size() - 1)
	
	# group
	self.add_to_group(PIANO_BUTTON_GROUP)
	
	# name text
	self.name = note
	self.text = "%s\n%s" % [note, qwerty_key]
	
	# action and focus modes
	self.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	self.focus_mode = Control.FOCUS_NONE
	
	# button group
	self.toggle_mode = true

	# black keys
	if is_black:
		min_y /= 2.0
		# min_x /= 2.0
	self.custom_minimum_size = Vector2(min_x, min_y)
	
	# signals
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	
	# for toggle / untoggle button
	self.pressed.connect(_on_piano_button_pressed)
	self.button_up.connect(_on_piano_button_up)
	
	
func _process(_delta:float) -> void:
	# fill buffer every frame
	if audio_player.playing:
		if playback:
			fill_buffer()

	# stop playing if click released and not qwerty key
	if Input.is_action_just_released("click") and self.is_hovering:
		if self.button_pressed:
			button_up.emit()


#func _input(event):
	#if event is InputEventScreenTouch:
		#if event.pressed:
			#if _is_touch_inside(event.position):
				#active_touches[event.index] = true
				#self.pressed.emit()
		#else:
			#if event.index in active_touches:
				#active_touches.erase(event.index)
				#if active_touches.is_empty():
					#self.button_up.emit()
	#
	#elif event is InputEventScreenDrag:
		#if event.index in active_touches and not _is_touch_inside(event.position):
			#active_touches.erase(event.index)
			#if active_touches.is_empty():
				#self.button_up.emit()
				
				
#func _is_touch_inside(pos: Vector2) -> bool:
	#return get_global_rect().has_point(pos)
	
	
	
	
	
func _on_piano_button_pressed(_qwerty:bool = false) -> void:
	self.qwerty = _qwerty
	print("qwerty = %s" % self.qwerty)
	print("down, %s, %s" % [self.note, self.freq])
	self.button_pressed = true
	play_freq()
	piano_button_pressed.emit(self)

func _on_piano_button_up() -> void:
	self.qwerty = false
	print("up, %s, %s" % [self.note, self.freq])
	self.button_pressed = false
	stop_freq()
	
	
func _on_mouse_entered() -> void:
	is_hovering = true
	if not self.qwerty:
		if Input.is_action_pressed("click"):
			pressed.emit()
		
func _on_mouse_exited() -> void:
	is_hovering = false
	if not self.qwerty:
		if self.button_pressed:
			button_up.emit()


# play the frequency
func play_freq() -> void:
	# reset tweener
	if volume_tweener:
		volume_tweener.kill()
	
	# reset phase
	self.phase = 0.0
	
	# attack
	audio_player.volume_db = -80.0
	var attack_time = attack_samples / mix_rate
	# print("attack_time = %s" % attack_time)
	# tween
	volume_tweener = create_tween()
	volume_tweener.finished.connect(func():
		decay_sustain()
	)
	volume_tweener.tween_property(audio_player, "volume_db", peak_db, attack_time)
	
	# play
	audio_player.play()
	
	# fill buffer
	playback = audio_player.get_stream_playback()
	fill_buffer()


func decay_sustain() -> void:
	# print("decay")
	var decay_time = decay_samples / mix_rate
	if volume_tweener:
		volume_tweener.kill()
	volume_tweener = create_tween()
	volume_tweener.finished.connect(func():
		# print("sustain")
		pass
	)
	volume_tweener.tween_property(audio_player, "volume_db", sus_db, decay_time)


func stop_freq(smooth:bool = true) -> void:
	if not audio_player.playing:
		return

	# release
	var release_time = release_samples / mix_rate
	
	if smooth:
		if volume_tweener:
			volume_tweener.kill()
		volume_tweener = create_tween()
		volume_tweener.finished.connect(func():
			audio_player.stop()
			pass
		)
		volume_tweener.tween_property(audio_player, "volume_db", -80.0, release_time)
	else:
		audio_player.stop()
		pass


#func fill_buffer():
	#var increment = freq / mix_rate
	#var frames_available = playback.get_frames_available()
	#
	## update waveform
	#var temp = current_waveform
	#var wave_keys = wave_table.keys()
	#var wave_count = wave_keys.size()
	#var index = int(waveform_index) % wave_count
	#current_waveform = wave_keys[index]
	#if temp != current_waveform:
		#print(current_waveform)
	#
	#var waveform:float
	#for i in range(frames_available):
		#waveform = wave_table[current_waveform].call(phase)
		#playback.push_frame(Vector2.ONE * waveform)
		#phase = fmod(phase + increment, 1.0)


func fill_buffer():
	var increment = freq / mix_rate
	var frames_available = playback.get_frames_available()
	var wave_keys = wave_table.keys()
	var wave_count = wave_keys.size()

	# Get lower and upper wave indices for interpolation
	var lower_index = int(waveform_index) % wave_count
	var upper_index = (lower_index + 1) % wave_count
	var blend_factor = waveform_index - lower_index  # Fractional part

	var lower_waveform = wave_table[wave_keys[lower_index]]
	var upper_waveform = wave_table[wave_keys[upper_index]]

	# Amplitude normalization factors per waveform
	var normalization_factors = {
		"sin": 1.0,  # Already normalized
		"sawtooth": 0.707,  # Reduce harshness
		"triangle": 0.707,  # Similar to sine
		"pulse": 0.5  # Very loud, needs reduction
	}

	for i in range(frames_available):
		var lower_value = lower_waveform.call(phase) * normalization_factors[wave_keys[lower_index]]
		var upper_value = upper_waveform.call(phase) * normalization_factors[wave_keys[upper_index]]
		
		# Interpolate between the two waveforms
		var waveform = lerp(lower_value, upper_value, blend_factor)

		playback.push_frame(Vector2.ONE * waveform)
		phase = fmod(phase + increment, 1.0)
