class_name PianoButton
extends Button

@export var qwerty_key:String = "Y"

@export var note:String = "A4"
@export var freq:float = -1.0

@export var is_black:bool = false

@export var min_x:float = 64.0
@export var min_y:float = 200.0


var mix_rate:float = 11025.0
var fade_samples = mix_rate
@export var buffer_length:float = 0.5

var volume_tweener:Tween
@onready var audio_player:AudioStreamPlayer = self.create_audio_player()
@onready var playback:AudioStreamPlayback
@onready var sample_hz:float = audio_player.stream.mix_rate

var phase: float = 0.0




var is_hovering:bool = false
# const PIANO_BUTTON_GROUP = preload("res://piano_button_group.tres")
const PIANO_BUTTON_GROUP = "piano_button"


func create_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = mix_rate
	stream.buffer_length = buffer_length
	player.stream = stream
	self.add_child(player)
	return player


func _ready() -> void:
	self.add_to_group(PIANO_BUTTON_GROUP)
	
	self.name = note
	self.text = "%s\n%s" % [note, qwerty_key]
	
	self.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	self.focus_mode = Control.FOCUS_NONE
	
	# button group
	self.toggle_mode = true
	
	# self.button_group = PIANO_BUTTON_GROUP
	
	# black keys
	if is_black:
		min_y /= 2.0
	self.custom_minimum_size = Vector2(min_x, min_y)
	
	# signals
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	
	
	self.pressed.connect(_on_piano_button_pressed)
	self.button_up.connect(_on_piano_button_up)
	# self.toggled.connect(_on_piano_button_toggled)
	
	
func _process(_delta:float) -> void:
	if audio_player.playing:
		if playback:
			fill_buffer()
	
	# play if hovering and clicked
	#if is_hovering:
		#if Input.is_action_pressed("click"):
			#if self.button_pressed == false:
				#print("gui press: %s" % self.note)
				#pressed.emit()
				## self.button_pressed = true
				## self.toggled.emit(true)
	#
	# stop playing if click released
	if Input.is_action_just_released("click"):
		if self.button_pressed: # or audio_player.playing:
			# print("gui release: %s" % self.note)
			button_up.emit()
			# self.button_pressed = false
			# self.toggled.emit(false, get_stack()[0]["function"])
			# pass


func _on_piano_button_pressed() -> void:
	print("down, %s" % self.name)
	self.button_pressed = true
	# _press(self)
	play_freq()

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
	#if self.button_pressed or audio_player.playing:
		#print("hover release: %s" % self.note)
		#self.button_pressed = false
		#self.toggled.emit(false)


func _press(btn:BaseButton, focus:bool=false) -> void:
	if btn.is_inside_tree():
		btn.emit_signal("pressed")
		btn.button_pressed = true
		if focus:
			btn.grab_focus()
	else:
		push_warning("%s is not inside tree" % btn)
		
		
func play_freq() -> void:
	# play the frequency
	if volume_tweener:
		volume_tweener.kill()
	audio_player.volume_db = 0.0
	audio_player.play()
	playback = audio_player.get_stream_playback()
	fill_buffer()


func stop_freq(smooth:bool = true) -> void:
	if not audio_player.playing:
		return

	var fade_time = fade_samples / mix_rate
	
	if smooth:
		if volume_tweener:
			volume_tweener.kill()
		volume_tweener = create_tween()
		volume_tweener.finished.connect(func():
			audio_player.stop()
			pass
		)
		volume_tweener.tween_property(audio_player, "volume_db", -80.0, fade_time)
	else:
		audio_player.stop()
		pass
	
	

func fill_buffer():
	# var phase = 0.0
	var increment = freq / mix_rate
	var frames_available = playback.get_frames_available()

	for i in range(frames_available):
		playback.push_frame(Vector2.ONE * sin(phase * TAU))
		phase = fmod(phase + increment, 1.0)
