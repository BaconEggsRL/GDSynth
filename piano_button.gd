class_name PianoButton
extends Button

@export var qwerty_key:String = "Y"
@export var note:String = "A4"
@export var freq:float = 440.0
@export var is_black:bool = false

@export var min_x:float = 64.0
@export var min_y:float = 200.0

var is_hovering:bool = false
const PIANO_BUTTON_GROUP = preload("res://piano_button_group.tres")

func _ready() -> void:
	self.name = note
	self.text = "%s\n%s" % [note, qwerty_key]
	
	self.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	self.focus_mode = Control.FOCUS_NONE
	
	# button group
	self.toggle_mode = true
	self.button_group = PIANO_BUTTON_GROUP
	
	# black keys
	if is_black:
		min_y /= 2.0
	self.custom_minimum_size = Vector2(min_x, min_y)
	
	# signals
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	
	
func _process(_delta:float) -> void:
	if is_hovering:
		if Input.is_action_pressed("click"):
			print("gui press: %s" % self.note)
			self.button_pressed = true
			self.toggled.emit(true)
	
	if Input.is_action_just_released("click"):
		print("gui release: %s" % self.note)
		self.button_pressed = false
		self.toggled.emit(false)
	

func _on_mouse_entered() -> void:
	is_hovering = true
	

func _on_mouse_exited() -> void:
	is_hovering = false
