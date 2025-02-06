extends SpinBox

const NORMAL_LINEEDIT_STYLE = preload("res://normal_lineedit_style.tres")
@onready var line = get_line_edit()

func _ready():
	# Ensure SpinBox itself can't grab focus
	focus_mode = Control.FOCUS_NONE
	
	# line.focus_mode = Control.FOCUS_NONE
	# line.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Prevent mouse clicks from selecting it
	# Remove focus border from internal line edit
	line.add_theme_stylebox_override("focus", NORMAL_LINEEDIT_STYLE)
	
	# Remove focus from LineEdit after it grabs it
	line.text_changed.connect(_on_text_changed)
	self.value_changed.connect(_on_value_changed)

func _on_text_changed(_new_text):        
	line.release_focus()

func _on_value_changed(_value):        
	line.release_focus()
