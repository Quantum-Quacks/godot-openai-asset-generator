@tool
extends EditorPlugin

## Plugin principal para el generador de imágenes con OpenAI

var dock_instance
var bulk_dock_instance

func _enter_tree():
	# Agregar el dock principal
	dock_instance = preload("res://addons/openai_image_generator/image_generator_dock.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock_instance)
	
	# Agregar el dock de generación en bulk
	bulk_dock_instance = preload("res://addons/openai_image_generator/bulk_image_generator_dock.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, bulk_dock_instance)
	
	print("Plugin OpenAI Image Generator activado con dock de bulk")

func _exit_tree():
	# Remover los docks
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
	
	if bulk_dock_instance:
		remove_control_from_docks(bulk_dock_instance)
		bulk_dock_instance.queue_free()
	
	print("Plugin OpenAI Image Generator desactivado")
