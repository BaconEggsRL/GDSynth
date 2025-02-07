extends VSlider

var bus_index = AudioServer.get_bus_index("Master")  # Change to your target audio bus

func _ready():
	# Set slider range (ensure this matches your Inspector settings)
	min_value = 0.0
	max_value = 1.0
	step = 0.01  # Optional for smoother adjustments

	# Load and apply saved volume
	value = get_stored_volume()
	update_volume(value)

	# Connect the slider's value change signal to the function
	value_changed.connect(_on_value_changed)

func _on_value_changed(_value):
	update_volume(_value)
	store_volume(_value)  # Save setting

func update_volume(_value):
	var db = linear_to_db(_value)  # Convert linear scale (0-1) to decibels
	AudioServer.set_bus_volume_db(bus_index, db)

func store_volume(_value):
	var config = ConfigFile.new()
	config.set_value("audio", "volume", _value)
	config.save("user://settings.cfg")

func get_stored_volume():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("audio", "volume", 1.0)
	return 1.0
