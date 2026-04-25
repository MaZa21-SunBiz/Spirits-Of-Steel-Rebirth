extends SpinBox

func _ready():
	var line_edit = get_line_edit()
	line_edit.connect("text_changed", Callable(self, "_on_line_edit_text_changed"))

func _on_line_edit_text_changed(new_text: String):
	var filtered = ""
	var is_first_char = true
	var has_decimal = false
	
	for c in new_text:
		# Allow digits
		if c.is_valid_int():
			filtered += c
		# Allow one minus sign at the beginning
		elif is_first_char and c == '-':
			filtered += c
		# Allow one decimal point if your SpinBox uses floats
		elif c == '.' and not has_decimal and "float" in str(step):  # Adjust condition as needed
			filtered += c
			has_decimal = true
		# Ignore all other characters
		is_first_char = false
	
	# Update the line edit text only if it changed
	if filtered != new_text:
		var line_edit = get_line_edit()
		line_edit.text = filtered
		line_edit.caret_column = filtered.length()
	
	if filtered != "" and filtered != "-":
		var val = float(filtered)
		if val > max_value:
			val = max_value
			filtered = str(int(val)) # Use int for division count
			get_line_edit().text = filtered
			
		if val != value:
			value = val
			# Ensure the caret doesn't jump if value setting reformats text
			get_line_edit().caret_column = filtered.length()
