extends HBoxContainer

@onready var osc_speed_slider: HSlider = $OscSpeedSlider
@onready var osc_speed_label: Label = $OscSpeedLabel

var str_format = "%.1fs"

func _ready():
	# Set initial label text
	osc_speed_label.text = str_format % osc_speed_slider.value
	
	# Connect the slider's value_changed signal to update the label
	osc_speed_slider.value_changed.connect(update_label)

func update_label(value):
	# Update the label text with the slider value
	osc_speed_label.text = str_format % value
