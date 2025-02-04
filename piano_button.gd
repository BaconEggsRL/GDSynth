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

var is_hovering:bool = false
const PIANO_BUTTON_GROUP = "piano_button"

signal piano_button_pressed


func create_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = mix_rate
	stream.buffer_length = buffer_length
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM  # required for web build
	
	self.add_child(player)
	return player


func _ready() -> void:
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

	# stop playing if click released
	if Input.is_action_just_released("click"):
		if self.button_pressed:
			button_up.emit()



func _on_piano_button_pressed() -> void:
	print("down, %s" % self.name)
	self.button_pressed = true
	play_freq()
	piano_button_pressed.emit(self)

func _on_piano_button_up() -> void:
	print("up, %s" % self.name)
	self.button_pressed = false
	stop_freq()
	
	
func _on_mouse_entered() -> void:
	is_hovering = true
	if Input.is_action_pressed("click"):
		pressed.emit()
		
func _on_mouse_exited() -> void:
	is_hovering = false
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
	print("attack_time = %s" % attack_time)
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
	print("decay")
	var decay_time = decay_samples / mix_rate
	if volume_tweener:
		volume_tweener.kill()
	volume_tweener = create_tween()
	volume_tweener.finished.connect(func():
		print("sustain")
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
	## var phase = 0.0
	#var increment = freq / mix_rate
	#var frames_available = playback.get_frames_available()
#
	#for i in range(frames_available):
		#playback.push_frame(Vector2.ONE * sin(phase * TAU))
		#phase = fmod(phase + increment, 1.0)


func fill_buffer():
	# var phase:float = 0.0
	var increment = freq / mix_rate
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
		
		
