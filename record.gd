extends Button

func _ready() -> void:
	self.text = "Start Recording"


func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		self.text = "Stop Recording"
	else:
		self.text = "Start Recording"
