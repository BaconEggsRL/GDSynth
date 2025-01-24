extends Button

var record_test = "Record"
var stop_text = "Stop"

var effect:AudioEffectRecord
var recording:AudioStreamWAV


func _ready() -> void:
	# We get the index of the "Record" bus.
	var idx = AudioServer.get_bus_index("Master")
	# And use it to retrieve its first effect, which has been defined
	# as an "AudioEffectRecord" resource.
	effect = AudioServer.get_bus_effect(idx, 0)
	self.text = record_test


func _on_toggled(_toggled_on: bool) -> void:
	if effect.is_recording_active():
		self.text = record_test
		recording = effect.get_recording()
		effect.set_recording_active(false)
		
		# $PlayButton.disabled = false
		# $SaveButton.disabled = false
		
		# $RecordButton.text = "Record"
		# $Status.text = ""
	else:
		self.text = stop_text
		effect.set_recording_active(true)
		
		# $PlayButton.disabled = true
		# $SaveButton.disabled = true
		
		# $RecordButton.text = "Stop"
		# $Status.text = "Recording..."
