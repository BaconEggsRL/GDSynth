@tool
extends Node2D

@export var pos_init:Vector2 = Vector2(210.0, 130.0)
@export var spacing:float = 164.0

@export var update_positions_triggered: bool = false:
	get:
		return _update_positions_triggered
	set(value):
		if value and not _updating:  # Prevent recursion if already updating
			_updating = true
			set_update_positions(value)
			_updating = false

var _update_positions_triggered: bool = false  # Actual variable storage
var _updating: bool = false  # Flag to prevent infinite recursion

# Setter for the update_positions_triggered variable
func set_update_positions(value: bool) -> void:
	if value:  # If the checkbox is checked, update positions
		update_positions()
	_update_positions_triggered = false  # Reset the checkbox after triggering

# Function to update positions of child nodes
func update_positions() -> void:
	var i = 0
	for c:Knob in self.get_children():
		if i == 0:
			c.position = pos_init
		else:
			c.position = pos_init + (i * Vector2(spacing, 0.0))
		i += 1
