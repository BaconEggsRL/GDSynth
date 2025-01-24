class_name PianoButton
extends Button

@export var qwerty_key:String = "Y"
@export var note:String = "A4"
@export var freq:float = 440.0

@export var min_x:float = 32.0
@export var min_y:float = 200.0

func _ready() -> void:
	self.text = "%s\n%s" % [note, qwerty_key]
	self.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	self.focus_mode = Control.FOCUS_NONE
	self.custom_minimum_size = Vector2(min_x, min_y)
