extends Control



func _on_create_profile_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/create_profile.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
