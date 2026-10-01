extends ConfirmationDialog


## Keep Escape local to the modal instead of closing the underlying dossier.
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		set_input_as_handled()
		hide()
		canceled.emit()
