extends Node

@export var StartsUI: Control
@export var SettingsUI: Node2D
@export var CreditsUI: Control

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_new_game_pressed() -> void:
	# get_tree().change_scene_to_packed(preload("res://Scenes/world.tscn"))
	StartsUI.visible = !StartsUI.visible
	KeyboardManager.settings.visible = false
func _on_settings_pressed() -> void:
	KeyboardManager.settings.visible = !KeyboardManager.settings.visible

func _on_exit_settings_pressed() -> void:
	SettingsUI.visible = false

func _on_credits_pressed() -> void:
	CreditsUI.visible = !CreditsUI.visible
	KeyboardManager.settings.visible = false

func _on_exit_credits_pressed() -> void:
	CreditsUI.visible = false
