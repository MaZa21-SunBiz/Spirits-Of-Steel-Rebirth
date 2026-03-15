extends CanvasLayer

@onready var progress_bar: ProgressBar = $Panel/ProgressBar
@onready var status_label: Label = $Panel/Label
@onready var panel: Panel = $Panel

func _ready() -> void:
	# Start invisible
	panel.modulate.a = 0
	hide()

func set_progress(value: float) -> void:
	progress_bar.value = value * 100

func show_screen() -> void:
	if not is_node_ready():
		await ready
	
	show()
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

func hide_screen() -> void:
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished
	hide()
