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
var current_freq:float = -1.0

@export var is_black:bool = false

@export var min_x:float = 64.0
@export var min_y:float = 200.0


var mix_rate:float = 11025.0
var release_samples = mix_rate
var attack_samples = mix_rate

var buffer_length:float = 0.015  # 0.050

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
	"triangle": func(_phase): return 1.0 - 4.0 * abs(round(_phase - 0.25) - (_phase - 0.25)),
	"sawtooth": func(_phase): return 2.0 * _phase - 1.0,
	"pulse": func(_phase): return 1.0 if _phase < 0.5 else -1.0
}
var waveform_index: float = 0.0

var waveform_target_index: float = 0.0
var tween:Tween


# pitch mod
var pending_pitch_change: float = 1.0  # Stores the next pitch shift
var apply_pitch_change: bool = false   # Flag to apply pitch change
var prev_waveform: float = 0.0         # Tracks the previous sample value


# wave mod
var pending_waveform_change: float = 0.0  # Stores the next wave shift
var apply_waveform_change: bool = false   # Flag to apply pitch change



	
	
func create_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = mix_rate
	stream.buffer_length = buffer_length
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # required for web build
	
	self.add_child(player)
	return player


#func _start_waveform_tween(target_index:int = wave_table.keys().size() - 1):
	#tween = create_tween()
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(self, "waveform_index", target_index, tween_time)
	#tween.finished.connect(_restart_waveform_tween)
	#tween.play()
#
#
#func _restart_waveform_tween(target_index:int = 0):
	#tween = create_tween()
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(self, "waveform_index", target_index, tween_time)
	#tween.finished.connect(_start_waveform_tween)
	#tween.play()
	

func queue_pitch_change(target_scale:float) -> void:
	# print("pitch change")
	pending_pitch_change = target_scale
	apply_pitch_change = true  # Set flag to apply change on zero crossing


func queue_waveform_change(idx:float) -> void:
	# print("waveform change")
	self.waveform_index = idx
	# pending_waveform_change = idx
	# apply_waveform_change = true  # Set flag to apply change on zero crossing
	
	
	
func _ready() -> void:
	# waveform tweener
	# _start_waveform_tween(wave_table.keys().size() - 1)
	
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


func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_touch_inside(event.position):
				active_touches[event.index] = true
				self.pressed.emit()
		else:
			if event.index in active_touches:
				active_touches.erase(event.index)
				if active_touches.is_empty():
					self.button_up.emit()
	
	elif event is InputEventScreenDrag:
		if event.index in active_touches and not _is_touch_inside(event.position):
			active_touches.erase(event.index)
			if active_touches.is_empty():
				self.button_up.emit()
				
				
func _is_touch_inside(pos: Vector2) -> bool:
	return get_global_rect().has_point(pos)
	
	
	
	
	
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



func fill_buffer():
	# print("fill buffer")
	
	var frames_available = playback.get_frames_available()
	var wave_keys = wave_table.keys()
	var wave_count = wave_keys.size()

	# Get lower and upper wave indices for interpolation
	var lower_index = int(waveform_index) % wave_count
	# var upper_index = (lower_index + 1) % wave_count
	# var blend_factor = waveform_index - lower_index  # Fractional part

	var lower_waveform = wave_table[wave_keys[lower_index]]
	# var upper_waveform = wave_table[wave_keys[upper_index]]

	# Amplitude normalization factors per waveform
	var normalization_factors = {
		"sin": 1.0,  # Already normalized
		"sawtooth": 0.707,  # Reduce harshness
		"triangle": 0.707,  # Similar to sine
		"pulse": 0.5  # Very loud, needs reduction
	}

	for i in range(frames_available):
		# Interpolate between waveforms
		var lower_value = lower_waveform.call(phase) * normalization_factors[wave_keys[lower_index]]
		# var upper_value = upper_waveform.call(phase) * normalization_factors[wave_keys[upper_index]]
		# var waveform = lerp(lower_value, upper_value, blend_factor)  
		var waveform = lower_value
		
		# Zero-crossing detection: Apply pitch change only when crossing zero
		# var _tol = 0.1
		if apply_pitch_change: # and abs(waveform) < tol:
		# if apply_pitch_change and ((prev_waveform < tol and waveform >= tol) or (prev_waveform > tol and waveform <= tol)):
			current_freq = freq * pending_pitch_change
			# freq *= pending_pitch_change  # Apply pitch shift only at zero crossing
			apply_pitch_change = false  # Reset flag until the next change request
		
		# Push waveform and update phase
		playback.push_frame(Vector2.ONE * waveform)
		prev_waveform = waveform  # Store previous value for next iteration
		phase = fmod(phase + (current_freq / mix_rate), 1.0)
