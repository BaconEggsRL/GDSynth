class_name LabeledSlider
extends HBoxContainer

@export var slider: Slider
@export var label: Label

var str_format: String
@export var use_BPM: bool = false

func _ready():
	# Set string format
	if use_BPM:
		str_format = "%.2f s / %s BPM"
		label.text = str_format % [slider.value, 60.0/slider.value]
	else:
		str_format = "%.2f s"
		label.text = str_format % [slider.value]
	
	# Connect the slider's value_changed signal to update the label
	slider.value_changed.connect(update_label)

func update_label(value):
	# Update the label text with the slider value
	if use_BPM:
		label.text = str_format % [value, 60.0/value]
	else:
		label.text = str_format % [value]
