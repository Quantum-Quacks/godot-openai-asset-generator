@tool
extends Control

## Dock principal para el generador de imágenes con OpenAI

# Constantes para la API
const API_URL = "https://api.openai.com/v1/images/generations"
const DEFAULT_MODEL = "gpt-image-1"

# Variables para la UI
var api_key_input: LineEdit
var prompt_input: TextEdit
var preset_prompts_option: OptionButton
var apply_preset_button: Button
var model_option: OptionButton
var size_option: OptionButton
var quality_option: OptionButton
var background_option: OptionButton
var count_input: SpinBox
var output_folder_input: LineEdit
var folder_button: Button
var generate_button: Button
var status_label: Label
var progress_bar: ProgressBar

# Variables para la generación
var http_request: HTTPRequest
var output_folder: String = "res://assets/openai_generations"
var is_generating: bool = false
var current_index: int = 0
var total_images: int = 0
var file_dialog: EditorFileDialog
var config_file: ConfigFile
var config_path: String = "res://addons/openai_image_generator/config.cfg"
var preset_prompts: Dictionary = {}

func _init():
    name = "OpenAI Images"
    _load_config()
    
    # Configurar el layout principal
    var main_vbox = VBoxContainer.new()
    main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(main_vbox)
    
    # Sección de API Key
    var api_key_hbox = HBoxContainer.new()
    var api_key_label = Label.new()
    api_key_label.text = "API Key:"
    api_key_hbox.add_child(api_key_label)
    
    api_key_input = LineEdit.new()
    api_key_input.secret = true
    api_key_input.placeholder_text = "Ingresa tu API Key de OpenAI"
    api_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    api_key_hbox.add_child(api_key_input)
    
    main_vbox.add_child(api_key_hbox)
    
    # Sección de Prompts Predefinidos
    var preset_label = Label.new()
    preset_label.text = "Prompts Predefinidos:"
    main_vbox.add_child(preset_label)
    
    var preset_hbox = HBoxContainer.new()
    
    preset_prompts_option = OptionButton.new()
    preset_prompts_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preset_hbox.add_child(preset_prompts_option)
    
    apply_preset_button = Button.new()
    apply_preset_button.text = "Aplicar"
    apply_preset_button.connect("pressed", _on_apply_preset_pressed)
    preset_hbox.add_child(apply_preset_button)
    
    main_vbox.add_child(preset_hbox)
    
    # Sección de Prompt
    var prompt_label = Label.new()
    prompt_label.text = "Prompt:"
    main_vbox.add_child(prompt_label)
    
    prompt_input = TextEdit.new()
    prompt_input.placeholder_text = "Describe la imagen que deseas generar o selecciona un prompt predefinido"
    prompt_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
    prompt_input.custom_minimum_size.y = 100
    main_vbox.add_child(prompt_input)
    
    # Sección de opciones
    var options_grid = GridContainer.new()
    options_grid.columns = 2
    options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(options_grid)
    
    # Modelo
    var model_label = Label.new()
    model_label.text = "Modelo:"
    options_grid.add_child(model_label)
    
    model_option = OptionButton.new()
    model_option.add_item("GPT Image 1", 0)
    model_option.select(0)
    options_grid.add_child(model_option)
    
    # Tamaño
    var size_label = Label.new()
    size_label.text = "Tamaño:"
    options_grid.add_child(size_label)
    
    size_option = OptionButton.new()
    size_option.add_item("1024x1024", 0)
    size_option.add_item("1024x1792", 1)
    size_option.add_item("1792x1024", 2)
    size_option.select(0)
    options_grid.add_child(size_option)
    
    # Calidad (CORREGIDO)
    var quality_label = Label.new()
    quality_label.text = "Calidad:"
    options_grid.add_child(quality_label)
    
    # En la función _init(), cambiar las opciones del dropdown:
    quality_option = OptionButton.new()
    quality_option.add_item("Low", 0)
    quality_option.add_item("Medium", 1)
    quality_option.add_item("High", 2)
    quality_option.add_item("Auto", 3)

    quality_option.select(1)  # Medium por defecto
    options_grid.add_child(quality_option)
    
    # Fondo
    var background_label = Label.new()
    background_label.text = "Fondo:"
    options_grid.add_child(background_label)
    
    background_option = OptionButton.new()
    background_option.add_item("Transparente", 0)
    background_option.add_item("Color", 1)
    background_option.select(0)
    options_grid.add_child(background_option)
    
    # Cantidad
    var count_label = Label.new()
    count_label.text = "Cantidad:"
    options_grid.add_child(count_label)
    
    count_input = SpinBox.new()
    count_input.min_value = 1
    count_input.max_value = 10
    count_input.value = 1
    options_grid.add_child(count_input)
    
    # Carpeta de salida
    var folder_hbox = HBoxContainer.new()
    var folder_label = Label.new()
    folder_label.text = "Carpeta de salida:"
    folder_hbox.add_child(folder_label)
    
    output_folder_input = LineEdit.new()
    output_folder_input.text = output_folder
    output_folder_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    folder_hbox.add_child(output_folder_input)
    
    folder_button = Button.new()
    folder_button.text = "..."
    folder_button.connect("pressed", _on_folder_button_pressed)
    folder_hbox.add_child(folder_button)
    
    main_vbox.add_child(folder_hbox)
    
    # Botón de generación
    generate_button = Button.new()
    generate_button.text = "Generar Imágenes"
    generate_button.connect("pressed", _on_generate_button_pressed)
    main_vbox.add_child(generate_button)
    
    # Barra de progreso
    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0
    progress_bar.max_value = 100
    progress_bar.value = 0
    progress_bar.visible = false
    main_vbox.add_child(progress_bar)
    
    # Etiqueta de estado
    status_label = Label.new()
    status_label.text = "Listo para generar imágenes"
    main_vbox.add_child(status_label)
    
    # Configurar HTTPRequest
    http_request = HTTPRequest.new()
    http_request.connect("request_completed", _on_request_completed)
    add_child(http_request)
    
    # Configurar FileDialog
    file_dialog = EditorFileDialog.new()
    file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
    file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
    file_dialog.connect("dir_selected", _on_dir_selected)
    add_child(file_dialog)
    
    # Cargar configuración guardada
    _apply_saved_config()
    _load_preset_prompts()

## Carga los prompts predefinidos desde el archivo de configuración
func _load_preset_prompts() -> void:
    preset_prompts.clear()
    preset_prompts_option.clear()
    
    # Agregar opción por defecto
    preset_prompts_option.add_item("-- Seleccionar Prompt --")
    
    if not config_file:
        return
    
    # Cargar prompts desde la sección [prompts] del config.cfg
    var prompts_section = config_file.get_section_keys("prompts")
    for key in prompts_section:
        var prompt_text = config_file.get_value("prompts", key, "")
        if not prompt_text.is_empty():
            # Formatear el nombre para mostrar
            var display_name = key.replace("_", " ").capitalize()
            preset_prompts[display_name] = prompt_text
            preset_prompts_option.add_item(display_name)
    
    print("[DEBUG] Prompts predefinidos cargados: ", preset_prompts.size())

## Maneja el evento de aplicar un prompt predefinido
func _on_apply_preset_pressed() -> void:
    var selected_index = preset_prompts_option.selected
    if selected_index <= 0:  # 0 es "-- Seleccionar Prompt --"
        return
    
    var selected_name = preset_prompts_option.get_item_text(selected_index)
    if preset_prompts.has(selected_name):
        prompt_input.text = preset_prompts[selected_name]
        print("[DEBUG] Prompt aplicado: ", selected_name)

func _load_config() -> void:
    config_file = ConfigFile.new()
    var err = config_file.load(config_path)
    if err != OK:
        # Si no existe el archivo de configuración, usar valores por defecto
        print("No se encontró archivo de configuración, usando valores por defecto")

## Aplica la configuración guardada a la interfaz
func _apply_saved_config() -> void:
    if not config_file:
        return
    
    # Cargar API key si existe
    var saved_api_key = config_file.get_value("openai", "api_key", "")
    if not saved_api_key.is_empty():
        api_key_input.text = saved_api_key
    
    # Cargar configuraciones por defecto
    var default_size = config_file.get_value("defaults", "size", "1024x1024")
    for i in range(size_option.get_item_count()):
        if size_option.get_item_text(i) == default_size:
            size_option.select(i)
            break
    
    var default_quality = config_file.get_value("defaults", "quality", "standard")
    for i in range(quality_option.get_item_count()):
        if quality_option.get_item_text(i).to_lower() == default_quality:
            quality_option.select(i)
            break
    
    var default_background = config_file.get_value("defaults", "background", "transparent")
    background_option.select(0 if default_background == "transparent" else 1)
    
    var default_folder = config_file.get_value("defaults", "output_folder", "res://assets/openai_generations")
    output_folder = default_folder
    output_folder_input.text = default_folder

## Guarda la configuración actual
func _save_config() -> void:
    if not config_file:
        config_file = ConfigFile.new()
    
    # Guardar configuraciones actuales (sin la API key por seguridad)
    config_file.set_value("defaults", "size", size_option.get_item_text(size_option.selected))
    config_file.set_value("defaults", "quality", quality_option.get_item_text(quality_option.selected).to_lower())
    config_file.set_value("defaults", "background", "transparent" if background_option.selected == 0 else "color")
    config_file.set_value("defaults", "output_folder", output_folder)
    
    # Guardar archivo
    config_file.save(config_path)

## Valida la API key
func _validate_api_key(api_key: String) -> bool:
    return api_key.begins_with("sk-") and api_key.length() > 20

## Limpia y valida el prompt
func _validate_prompt(prompt: String) -> bool:
    return prompt.length() >= 10 and prompt.length() <= 1000

## Maneja el evento de presionar el botón de carpeta
func _on_folder_button_pressed() -> void:
    file_dialog.popup_centered_ratio(0.7)

## Maneja el evento de seleccionar un directorio
func _on_dir_selected(dir: String) -> void:
    output_folder = dir
    output_folder_input.text = dir
    
func _on_generate_button_pressed() -> void:
    print("[DEBUG] Iniciando generación de imágenes...")
    if is_generating:
        print("[DEBUG] Ya se está generando, cancelando...")
        return
    
    var api_key = api_key_input.text.strip_edges()
    if api_key.is_empty():
        print("[ERROR] API Key vacía")
        status_label.text = "Error: API Key no proporcionada"
        return
    
    if not _validate_api_key(api_key):
        print("[ERROR] API Key inválida: ", api_key.substr(0, 10) + "...")
        status_label.text = "Error: API Key inválida (debe comenzar con 'sk-')"
        return
    
    var prompt = prompt_input.text.strip_edges()
    if prompt.is_empty():
        print("[ERROR] Prompt vacío")
        status_label.text = "Error: Prompt no proporcionado"
        return
    
    if not _validate_prompt(prompt):
        print("[ERROR] Prompt inválido, longitud: ", prompt.length())
        status_label.text = "Error: Prompt debe tener entre 10 y 1000 caracteres"
        return
    
    print("[DEBUG] Validaciones pasadas. Prompt: ", prompt.substr(0, 50) + "...")
    
    # Asegurar que la carpeta de salida existe
    var dir = DirAccess.open("res://")
    if !dir.dir_exists(output_folder.trim_prefix("res://")):
        print("[DEBUG] Creando directorio: ", output_folder)
        dir.make_dir_recursive(output_folder.trim_prefix("res://"))
    
    # Preparar para la generación
    is_generating = true
    current_index = 0
    total_images = int(count_input.value)
    progress_bar.max_value = total_images
    progress_bar.value = 0
    progress_bar.visible = true
    status_label.text = "Generando imagen 1 de " + str(total_images) + "..."
    
    print("[DEBUG] Configuración: total_images=", total_images, ", output_folder=", output_folder)
    
    # Deshabilitar la interfaz durante la generación
    generate_button.disabled = true
    
    # Guardar configuración actual
    _save_config()
    
    # Iniciar la generación
    print("[DEBUG] Iniciando primera imagen...")
    _generate_next_image()

## Genera la siguiente imagen en la cola
func _generate_next_image() -> void:
    print("[DEBUG] _generate_next_image() - current_index: ", current_index, ", total_images: ", total_images)
    
    if current_index >= total_images:
        print("[DEBUG] Todas las imágenes generadas, finalizando...")
        _finish_generation()
        return
    
    current_index += 1
    status_label.text = "Generando imagen " + str(current_index) + " de " + str(total_images) + "..."
    progress_bar.value = current_index - 1
    
    print("[DEBUG] Generando imagen ", current_index, " de ", total_images)
    
    # Preparar los parámetros para la API
    var model = DEFAULT_MODEL  # Usar gpt-image-1
    var size = size_option.get_item_text(size_option.selected)
    
    # Mapear calidad correctamente para gpt-image-1 (solo soporta "standard" y "hd")
    var quality_text = quality_option.get_item_text(quality_option.selected)
    var quality = quality_text.to_lower()
    
    print("[DEBUG] Calidad mapeada de '", quality_text, "' a '", quality, "'")
    
    var data = {
        "model": model,
        "prompt": prompt_input.text,
        "n": 1,
        "size": size,
        "quality": quality
    }
    
    print("[DEBUG] Datos de la API: ", JSON.stringify(data))
    
    # Configurar los headers
    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key_input.text
    ]
    
    print("[DEBUG] Headers configurados (API key oculta)")
    
    # Configurar timeout
    http_request.timeout = 60.0
    print("[DEBUG] Timeout configurado a 60 segundos")
    
    # Realizar la solicitud
    print("[DEBUG] Enviando solicitud a: ", API_URL)
    var error = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
    if error != OK:
        print("[ERROR] Error al realizar la solicitud: ", error)
        status_label.text = "Error al realizar la solicitud: " + str(error)
        _finish_generation()
    else:
        print("[DEBUG] Solicitud enviada correctamente, esperando respuesta...")

## Maneja la respuesta de la API
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    print("[DEBUG] Respuesta recibida - result: ", result, ", response_code: ", response_code)
    print("[DEBUG] Headers de respuesta: ", headers)
    
    if result != HTTPRequest.RESULT_SUCCESS:
        print("[ERROR] Error de red: ", result)
        status_label.text = "Error de red: " + str(result)
        _finish_generation()
        return
    
    if response_code != 200:
        var response_text = body.get_string_from_utf8()
        print("[ERROR] Error de API (", response_code, "): ", response_text)
        status_label.text = "Error de API (" + str(response_code) + "): " + response_text
        _finish_generation()
        return
    
    print("[DEBUG] Respuesta exitosa, procesando...")
    
    # Procesar la respuesta
    var response_text = body.get_string_from_utf8()
    print("[DEBUG] Cuerpo de respuesta (primeros 200 chars): ", response_text.substr(0, 200))
    
    var response = JSON.parse_string(response_text)
    if response and "data" in response and response["data"].size() > 0:
        var image_data = response["data"][0]
        
        # Verificar si la respuesta contiene URL o base64
        if "url" in image_data:
            # DALL-E 3 devuelve URL
            var image_url = image_data["url"]
            print("[DEBUG] URL de imagen obtenida: ", image_url)
            _download_image(image_url)
        elif "b64_json" in image_data:
            # gpt-image-1 devuelve base64
            var base64_data = image_data["b64_json"]
            print("[DEBUG] Datos base64 obtenidos, longitud: ", base64_data.length())
            _save_image_from_base64(base64_data)
        else:
            print("[ERROR] Respuesta no contiene 'url' ni 'b64_json'")
            status_label.text = "Error: Formato de respuesta no reconocido"
            _finish_generation()
    else:
        print("[ERROR] Respuesta de API inválida: ", response)
        status_label.text = "Error: Respuesta de API inválida"
        _finish_generation()

## Descarga la imagen generada
func _download_image(url: String) -> void:
    print("[DEBUG] Iniciando descarga de imagen desde: ", url)
    
    var image_http_request = HTTPRequest.new()
    add_child(image_http_request)
    image_http_request.connect("request_completed", _on_image_download_completed)
    
    var error = image_http_request.request(url)
    if error != OK:
        print("[ERROR] Error al iniciar descarga de imagen: ", error)
        status_label.text = "Error al descargar la imagen: " + str(error)
        image_http_request.queue_free()
        _generate_next_image()
    else:
        print("[DEBUG] Descarga de imagen iniciada correctamente")

## Maneja la descarga completada de la imagen
func _on_image_download_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    print("[DEBUG] Descarga completada - result: ", result, ", response_code: ", response_code, ", tamaño: ", body.size())
    
    var image_http_request = get_children().filter(func(child): return child is HTTPRequest and child != http_request)[0]
    
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        print("[ERROR] Error en descarga de imagen - result: ", result, ", code: ", response_code)
        status_label.text = "Error al descargar la imagen: " + str(response_code)
        image_http_request.queue_free()
        _generate_next_image()
        return
    
    # Guardar la imagen
    var timestamp = Time.get_unix_time_from_system()
    var file_name = output_folder + "/image_" + str(current_index) + "_" + str(timestamp) + ".png"
    print("[DEBUG] Guardando imagen como: ", file_name)
    
    var image = Image.new()
    var error = image.load_png_from_buffer(body)
    if error != OK:
        print("[ERROR] Error al procesar imagen PNG: ", error)
        status_label.text = "Error al procesar la imagen: " + str(error)
        image_http_request.queue_free()
        _generate_next_image()
        return
    
    print("[DEBUG] Imagen cargada correctamente, tamaño: ", image.get_size())
    
    # Guardar la imagen en disco
    error = image.save_png(file_name)
    if error != OK:
        print("[ERROR] Error al guardar imagen en disco: ", error)
        status_label.text = "Error al guardar la imagen: " + str(error)
    else:
        print("[DEBUG] Imagen guardada exitosamente: ", file_name)
    
    # Continuar con la siguiente imagen
    image_http_request.queue_free()
    print("[DEBUG] Continuando con siguiente imagen...")
    _generate_next_image()

## Finaliza el proceso de generación
func _finish_generation() -> void:
    is_generating = false
    generate_button.disabled = false
    
    if current_index >= total_images:
        status_label.text = "Generación completada. " + str(total_images) + " imágenes generadas."
        # Actualizar el sistema de archivos para mostrar las nuevas imágenes
        EditorInterface.get_resource_filesystem().scan()
    else:
        status_label.text = "Generación interrumpida. " + str(current_index) + " de " + str(total_images) + " imágenes generadas."
    
    progress_bar.visible = false

## Guarda una imagen desde datos base64
func _save_image_from_base64(base64_data: String) -> void:
    print("[DEBUG] Procesando imagen desde base64...")
    
    # Decodificar base64 a bytes
    var image_bytes = Marshalls.base64_to_raw(base64_data)
    if image_bytes.size() == 0:
        print("[ERROR] Error al decodificar base64")
        status_label.text = "Error al decodificar imagen base64"
        _generate_next_image()
        return
    
    print("[DEBUG] Base64 decodificado, tamaño: ", image_bytes.size(), " bytes")
    
    # Crear imagen desde los bytes PNG
    var image = Image.new()
    var error = image.load_png_from_buffer(image_bytes)
    if error != OK:
        print("[ERROR] Error al cargar imagen PNG desde buffer: ", error)
        status_label.text = "Error al procesar imagen: " + str(error)
        _generate_next_image()
        return
    
    print("[DEBUG] Imagen cargada correctamente, tamaño: ", image.get_size())
    
    # Guardar la imagen
    var timestamp = Time.get_unix_time_from_system()
    var file_name = output_folder + "/image_" + str(current_index) + "_" + str(timestamp) + ".png"
    print("[DEBUG] Guardando imagen como: ", file_name)
    
    error = image.save_png(file_name)
    if error != OK:
        print("[ERROR] Error al guardar imagen: ", error)
        status_label.text = "Error al guardar imagen: " + str(error)
    else:
        print("[DEBUG] Imagen guardada exitosamente: ", file_name)
    
    # Continuar con la siguiente imagen
    print("[DEBUG] Continuando con siguiente imagen...")
    _generate_next_image()
