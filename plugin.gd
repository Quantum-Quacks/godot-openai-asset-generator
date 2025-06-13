@tool
extends EditorPlugin

const ImageGeneratorDock = preload("res://addons/openai_image_generator/image_generator_dock.gd")
var dock

## Se ejecuta cuando el plugin se activa
func _enter_tree():
    # Crear y agregar el dock al editor
    dock = ImageGeneratorDock.new()
    add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

## Se ejecuta cuando el plugin se desactiva
func _exit_tree():
    # Remover el dock del editor
    if dock:
        remove_control_from_docks(dock)
        dock.queue_free()
        dock = null
