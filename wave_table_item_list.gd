extends ItemList

var is_dragging: bool = false

func _ready():
	connect("gui_input", Callable(self, "_on_ItemList_gui_input"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _on_ItemList_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed  # Start or stop dragging
			if is_dragging:
				var clicked_index = get_item_at_position(event.position)
				if clicked_index != -1:
					select(clicked_index)
					emit_signal("item_selected", clicked_index)  # Emit signal

	elif event is InputEventMouseMotion and is_dragging:
		var hovered_index = get_item_at_position(event.position)
		if hovered_index != -1 and !is_selected(hovered_index):
			select(hovered_index)
			emit_signal("item_selected", hovered_index)  # Emit signal on drag

func _on_mouse_exited():
	is_dragging = false  # Stop dragging when mouse leaves
