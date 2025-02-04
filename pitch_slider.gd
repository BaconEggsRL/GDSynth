extends VSlider

var center_value = 0.0
var tween:Tween


func _on_drag_ended(_value_changed: bool) -> void:
	# self.value = center_value
	# value_changed.emit(center_value)
	var distance_from_center = abs(self.value)
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "value", center_value, 1.0 * distance_from_center)
