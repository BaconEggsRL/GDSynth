class_name PianoButton
extends Button


@export var note = "A4"
@export var freq:float = 440.0

func _ready() -> void:
	self.text = note
	self.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	self.focus_mode = Control.FOCUS_NONE
	self.custom_minimum_size = Vector2(64.0, 200.0)
