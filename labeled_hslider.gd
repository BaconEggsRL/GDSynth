class_name LabeledSlider
extends HBoxContainer

@export var slider: Slider
@export var label: Label

var str_format = "%.1f s"

func _ready():
	# Set initial label text
	label.text = str_format % slider.value
	
	# Connect the slider's value_changed signal to update the label
	slider.value_changed.connect(update_label)

func update_label(value):
	# Update the label text with the slider value
	label.text = str_format % value
