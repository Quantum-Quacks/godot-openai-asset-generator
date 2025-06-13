@tool
extends Control

## Dock para generación en bulk de imágenes con OpenAI
## Permite generar múltiples imágenes usando una lista de elementos y un prompt común

# Constantes para la API
const API_URL = "https://api.openai.com/v1/images/generations"
const DEFAULT_MODEL = "gpt-image-1"
const DEFAULT_SIZE = "1024x1024"
# Cambiar la constante por defecto
const DEFAULT_QUALITY = "medium"

# Variables para la UI
var api_key_input: LineEdit
var prompt_template_input: TextEdit
var elements_list_input: TextEdit
var model_option: OptionButton
var size_option: OptionButton
var quality_option: OptionButton
var background_option: OptionButton
var output_folder_input: LineEdit
var folder_button: Button
var generate_button: Button
var status_label: Label
var progress_bar: ProgressBar
var preview_label: Label

# Variables para la generación
var http_request: HTTPRequest
var output_folder: String = "res://assets/openai_generations/bulk"
var is_generating: bool = false
var current_element_index: int = 0
var elements_list: Array[String] = []
var file_dialog: EditorFileDialog
var config_file: ConfigFile
var config_path: String = "res://addons/openai_image_generator/config.cfg"

func _init():
	name = "OpenAI Bulk Images"
	print("[BULK_INIT] Inicializando dock de generación en bulk")
	_load_config()
	
	# Configurar el layout principal
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# Título
	var title_label = Label.new()
	title_label.text = "Generación en Bulk"
	title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_label)
	
	main_vbox.add_child(HSeparator.new())
	
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
	
	# Sección de Prompt Template
	var prompt_template_label = Label.new()
	prompt_template_label.text = "Prompt Template (usa [elemento] como placeholder):"
	main_vbox.add_child(prompt_template_label)
	
	prompt_template_input = TextEdit.new()
	prompt_template_input.placeholder_text = "Ejemplo: Crea una imagen de [elemento] con fondo transparente"
	prompt_template_input.custom_minimum_size.y = 80
	prompt_template_input.text = "A single [elemento] rendered in 3D with a slightly cartoon style, clean and stylized, using VRAY rendering. The object should be isolated with a transparent background (PNG), with soft shadows and no floor. The perspective must be side-view (orthographic), optimized for a 2D platformer game. The object should be easy to insert into scenes as a reusable asset."
	main_vbox.add_child(prompt_template_input)
	
	# Sección de Lista de Elementos
	var elements_label = Label.new()
	elements_label.text = "Lista de Elementos (uno por línea):"
	main_vbox.add_child(elements_label)
	
	elements_list_input = TextEdit.new()
	elements_list_input.placeholder_text = "vaca\nperro\npez\ngato\npájaro"
	elements_list_input.custom_minimum_size.y = 120
	main_vbox.add_child(elements_list_input)
	
	# Preview del primer prompt
	preview_label = Label.new()
	preview_label.text = "Preview: (ingresa elementos para ver el preview)"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_color_override("font_color", Color.GRAY)
	main_vbox.add_child(preview_label)
	
	# Conectar señales para actualizar preview
	prompt_template_input.text_changed.connect(_update_preview)
	elements_list_input.text_changed.connect(_update_preview)
	
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
	
	# Calidad
	var quality_label = Label.new()
	quality_label.text = "Calidad:"
	options_grid.add_child(quality_label)
	
	quality_option = OptionButton.new()
	quality_option.add_item("HD", 0)
	quality_option.add_item("Medium", 1)
	quality_option.add_item("Low", 2)
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
	generate_button.text = "Generar Imágenes en Bulk"
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
	status_label.text = "Listo para generar imágenes en bulk"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	print("[BULK_INIT] Dock de generación en bulk inicializado correctamente")

## Actualiza el preview del prompt con el primer elemento
func _update_preview() -> void:
	var template = prompt_template_input.text.strip_edges()
	var elements_text = elements_list_input.text.strip_edges()
	
	if template.is_empty():
		preview_label.text = "Preview: (ingresa un template para ver el preview)"
		return
	
	if elements_text.is_empty():
		preview_label.text = "Preview: (ingresa elementos para ver el preview)"
		return
	
	var elements = elements_text.split("\n")
	var first_element = ""
	for element in elements:
		var clean_element = element.strip_edges()
		if not clean_element.is_empty():
			first_element = clean_element
			break
	
	if first_element.is_empty():
		preview_label.text = "Preview: (ingresa elementos válidos para ver el preview)"
		return
	
	var preview_prompt = template.replace("[elemento]", first_element)
	preview_label.text = "Preview: " + preview_prompt

## Carga la configuración desde el archivo
func _load_config() -> void:
	print("[BULK_CONFIG] Cargando configuración desde: ", config_path)
	config_file = ConfigFile.new()
	var err = config_file.load(config_path)
	if err != OK:
		print("[BULK_CONFIG] No se encontró archivo de configuración (error: ", err, "), usando valores por defecto")
	else:
		print("[BULK_CONFIG] Configuración cargada exitosamente")

## Aplica la configuración guardada a la interfaz
func _apply_saved_config() -> void:
	print("[BULK_CONFIG] Aplicando configuración guardada")
	if not config_file:
		print("[BULK_CONFIG] No hay archivo de configuración disponible")
		return
	
	# Cargar API key si existe
	var saved_api_key = config_file.get_value("openai", "api_key", "")
	if not saved_api_key.is_empty():
		api_key_input.text = saved_api_key
		print("[BULK_CONFIG] API Key cargada desde configuración")
	else:
		print("[BULK_CONFIG] No se encontró API Key en configuración")
	
	# Cargar configuraciones por defecto
	var default_size = config_file.get_value("defaults", "size", "1024x1024")
	print("[BULK_CONFIG] Tamaño por defecto: ", default_size)
	for i in range(size_option.get_item_count()):
		if size_option.get_item_text(i) == default_size:
			size_option.select(i)
			print("[BULK_CONFIG] Tamaño seleccionado: ", default_size)
			break
	
	var default_quality = config_file.get_value("defaults", "quality", "standard")
	print("[BULK_CONFIG] Calidad por defecto: ", default_quality)
	for i in range(quality_option.get_item_count()):
		if quality_option.get_item_text(i).to_lower() == default_quality:
			quality_option.select(i)
			print("[BULK_CONFIG] Calidad seleccionada: ", default_quality)
			break
	
	var default_background = config_file.get_value("defaults", "background", "transparent")
	print("[BULK_CONFIG] Fondo por defecto: ", default_background)
	background_option.select(0 if default_background == "transparent" else 1)
	
	var default_folder = config_file.get_value("defaults", "output_folder", "res://assets/openai_generations")
	output_folder = default_folder + "/bulk"
	output_folder_input.text = output_folder
	print("[BULK_CONFIG] Carpeta de salida configurada: ", output_folder)

## Valida la API key
func _validate_api_key(api_key: String) -> bool:
	print("[BULK_VALIDATION] Validando API Key...")
	var is_valid = api_key.begins_with("sk-") and api_key.length() > 20
	print("[BULK_VALIDATION] API Key válida: ", is_valid, " (longitud: ", api_key.length(), ")")
	return is_valid

## Valida el template del prompt
func _validate_prompt_template(template: String) -> bool:
	print("[BULK_VALIDATION] Validando template de prompt...")
	var has_placeholder = template.contains("[elemento]")
	var min_length = template.length() >= 10
	print("[BULK_VALIDATION] Template válido - Contiene placeholder: ", has_placeholder, ", Longitud mínima: ", min_length, " (longitud: ", template.length(), ")")
	return min_length and has_placeholder

## Procesa la lista de elementos y elimina líneas vacías
func _process_elements_list(elements_text: String) -> Array[String]:
	print("[BULK_PROCESSING] Procesando lista de elementos...")
	var elements: Array[String] = []
	var lines = elements_text.split("\n")
	print("[BULK_PROCESSING] Líneas encontradas: ", lines.size())
	
	for i in range(lines.size()):
		var line = lines[i]
		var clean_line = line.strip_edges()
		if not clean_line.is_empty():
			elements.append(clean_line)
			print("[BULK_PROCESSING] Elemento ", elements.size(), ": '", clean_line, "'")
		else:
			print("[BULK_PROCESSING] Línea ", i + 1, " vacía, omitiendo")
	
	print("[BULK_PROCESSING] Total de elementos válidos: ", elements.size())
	return elements

## Maneja el evento de presionar el botón de carpeta
func _on_folder_button_pressed() -> void:
	print("[BULK_UI] Abriendo selector de carpeta")
	file_dialog.popup_centered_ratio(0.7)

## Maneja el evento de seleccionar un directorio
func _on_dir_selected(dir: String) -> void:
	print("[BULK_UI] Directorio seleccionado: ", dir)
	output_folder = dir
	output_folder_input.text = dir

## Maneja el evento de presionar el botón de generación
func _on_generate_button_pressed() -> void:
	print("[BULK_GENERATION] ========== INICIANDO GENERACIÓN EN BULK ==========")
	print("[BULK_GENERATION] Timestamp: ", Time.get_datetime_string_from_system())
	
	if is_generating:
		print("[BULK_GENERATION] ERROR: Ya se está generando, cancelando...")
		status_label.text = "Error: Ya hay una generación en progreso"
		return
	
	# Validaciones con logs detallados
	var api_key = api_key_input.text.strip_edges()
	print("[BULK_GENERATION] Validando API Key...")
	if api_key.is_empty():
		print("[BULK_GENERATION] ERROR: API Key vacía")
		status_label.text = "Error: API Key no proporcionada"
		return
	
	if not _validate_api_key(api_key):
		print("[BULK_GENERATION] ERROR: API Key inválida")
		status_label.text = "Error: API Key inválida (debe comenzar con 'sk-')"
		return
	
	var template = prompt_template_input.text.strip_edges()
	print("[BULK_GENERATION] Validando template de prompt: '", template.substr(0, 50), "...'")
	if template.is_empty():
		print("[BULK_GENERATION] ERROR: Template vacío")
		status_label.text = "Error: Template de prompt no proporcionado"
		return
	
	if not _validate_prompt_template(template):
		print("[BULK_GENERATION] ERROR: Template inválido")
		status_label.text = "Error: Template debe contener '[elemento]' y tener al menos 10 caracteres"
		return
	
	print("[BULK_GENERATION] Procesando lista de elementos...")
	elements_list = _process_elements_list(elements_list_input.text)
	if elements_list.is_empty():
		print("[BULK_GENERATION] ERROR: Lista de elementos vacía")
		status_label.text = "Error: Lista de elementos vacía"
		return
	
	print("[BULK_GENERATION] Elementos a procesar: ", elements_list.size())
	for i in range(elements_list.size()):
		print("[BULK_GENERATION] Elemento ", i + 1, ": '", elements_list[i], "'")
	
	# Verificar y crear carpeta de salida
	print("[BULK_GENERATION] Verificando carpeta de salida: ", output_folder)
	var dir = DirAccess.open("res://")
	if not dir:
		print("[BULK_GENERATION] ERROR: No se pudo acceder al directorio raíz")
		status_label.text = "Error: No se pudo acceder al directorio del proyecto"
		return
	
	var relative_path = output_folder.trim_prefix("res://")
	if not dir.dir_exists(relative_path):
		print("[BULK_GENERATION] Creando directorio: ", output_folder)
		var create_result = dir.make_dir_recursive(relative_path)
		if create_result != OK:
			print("[BULK_GENERATION] ERROR: No se pudo crear directorio (error: ", create_result, ")")
			status_label.text = "Error: No se pudo crear la carpeta de salida"
			return
		else:
			print("[BULK_GENERATION] Directorio creado exitosamente")
	else:
		print("[BULK_GENERATION] Directorio ya existe")
	
	# Preparar para la generación
	print("[BULK_GENERATION] Preparando generación...")
	is_generating = true
	current_element_index = 0
	progress_bar.max_value = elements_list.size()
	progress_bar.value = 0
	progress_bar.visible = true
	status_label.text = "Generando imagen 1 de " + str(elements_list.size()) + " (" + elements_list[0] + ")..."
	
	# Deshabilitar la interfaz durante la generación
	generate_button.disabled = true
	print("[BULK_GENERATION] Interfaz deshabilitada durante generación")
	
	# Iniciar la generación
	print("[BULK_GENERATION] Iniciando primera imagen...")
	_generate_next_image()

## Genera la siguiente imagen en la cola
func _generate_next_image() -> void:
	print("[BULK_API] ========== GENERANDO IMAGEN ", current_element_index + 1, " de ", elements_list.size(), " ==========")
	print("[BULK_API] current_element_index: ", current_element_index, ", total_elements: ", elements_list.size())
	
	if current_element_index >= elements_list.size():
		print("[BULK_API] Todas las imágenes generadas, finalizando...")
		_finish_generation()
		return
	
	var current_element = elements_list[current_element_index]
	status_label.text = "Generando imagen " + str(current_element_index + 1) + " de " + str(elements_list.size()) + " (" + current_element + ")..."
	progress_bar.value = current_element_index
	
	print("[BULK_API] Elemento actual: '", current_element, "'")
	
	# Crear el prompt específico reemplazando [elemento]
	var specific_prompt = prompt_template_input.text.replace("[elemento]", current_element)
	print("[BULK_API] Prompt específico generado: '", specific_prompt, "'")
	print("[BULK_API] Longitud del prompt: ", specific_prompt.length(), " caracteres")
	
	# Preparar los parámetros para la API usando gpt-image-1
	var model = DEFAULT_MODEL  # Ahora usa "gpt-image-1"
	var size = size_option.get_item_text(size_option.selected)
	
	# Mapear calidad correctamente
	var quality_text = quality_option.get_item_text(quality_option.selected).to_lower()
	var quality = quality_text  # Usar directamente el valor seleccionado
	
	print("[BULK_API] Configuración de API:")
	print("[BULK_API]   - Modelo: ", model)
	print("[BULK_API]   - Tamaño: ", size)
	print("[BULK_API]   - Calidad: ", quality, " (seleccionado: ", quality_text, ")")
	
	var data = {
		"model": model,
		"prompt": specific_prompt,
		"n": 1,
		"size": size,
		"quality": quality
	}
	
	print("[BULK_API] Payload JSON: ", JSON.stringify(data))
	
	# Configurar los headers
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key_input.text
	]
	
	print("[BULK_API] Headers configurados (API key oculta por seguridad)")
	print("[BULK_API] Content-Type: application/json")
	print("[BULK_API] Authorization: Bearer [HIDDEN]")
	
	# Configurar timeout
	http_request.timeout = 60.0
	print("[BULK_API] Timeout configurado: ", http_request.timeout, " segundos")
	
	# Realizar la solicitud
	print("[BULK_API] Enviando solicitud HTTP POST a: ", API_URL)
	var request_start_time = Time.get_unix_time_from_system()
	print("[BULK_API] Timestamp de inicio: ", request_start_time)
	
	var error = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if error != OK:
		print("[BULK_API] ERROR: Fallo al realizar la solicitud HTTP (error code: ", error, ")")
		print("[BULK_API] Descripción del error: ", _get_http_request_error_description(error))
		status_label.text = "Error al realizar la solicitud: " + str(error)
		_finish_generation()
	else:
		print("[BULK_API] Solicitud HTTP enviada correctamente, esperando respuesta...")

## Obtiene descripción del error de HTTPRequest
func _get_http_request_error_description(error_code: int) -> String:
	match error_code:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "RESULT_CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "RESULT_CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "RESULT_CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "RESULT_CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "RESULT_TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "RESULT_NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "RESULT_BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "RESULT_REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "RESULT_DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "RESULT_DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "RESULT_REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return "RESULT_TIMEOUT"
		_:
			return "ERROR_UNKNOWN (" + str(error_code) + ")"

## Maneja la respuesta de la API
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_time = Time.get_unix_time_from_system()
	print("[BULK_RESPONSE] ========== RESPUESTA RECIBIDA ==========")
	print("[BULK_RESPONSE] Timestamp: ", response_time)
	print("[BULK_RESPONSE] Result code: ", result, " (", _get_http_request_error_description(result), ")")
	print("[BULK_RESPONSE] HTTP status: ", response_code)
	print("[BULK_RESPONSE] Headers count: ", headers.size())
	print("[BULK_RESPONSE] Body size: ", body.size(), " bytes")
	
	# Log de headers de respuesta
	for i in range(headers.size()):
		print("[BULK_RESPONSE] Header ", i, ": ", headers[i])
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[BULK_RESPONSE] ERROR: Fallo de red (result: ", result, ")")
		print("[BULK_RESPONSE] Descripción: ", _get_http_request_error_description(result))
		status_label.text = "Error de red: " + _get_http_request_error_description(result)
		_finish_generation()
		return
	
	if response_code != 200:
		var response_text = body.get_string_from_utf8()
		print("[BULK_RESPONSE] ERROR: HTTP status no exitoso (", response_code, ")")
		print("[BULK_RESPONSE] Cuerpo de error: ", response_text)
		
		# Intentar parsear error JSON
		var error_json = JSON.parse_string(response_text)
		if error_json and "error" in error_json:
			print("[BULK_RESPONSE] Error de API parseado: ", error_json.error)
			if "message" in error_json.error:
				print("[BULK_RESPONSE] Mensaje de error: ", error_json.error.message)
		
		status_label.text = "Error de API (" + str(response_code) + "): " + response_text.substr(0, 100)
		_finish_generation()
		return
	
	print("[BULK_RESPONSE] Respuesta exitosa, procesando...")
	
	# Procesar la respuesta
	var response_text = body.get_string_from_utf8()
	print("[BULK_RESPONSE] Cuerpo de respuesta (primeros 200 chars): ", response_text.substr(0, 200))
	
	var response = JSON.parse_string(response_text)
	if not response:
		print("[BULK_RESPONSE] ERROR: No se pudo parsear JSON de respuesta")
		status_label.text = "Error: Respuesta JSON inválida"
		_finish_generation()
		return
	
	print("[BULK_RESPONSE] JSON parseado exitosamente")
	print("[BULK_RESPONSE] Claves en respuesta: ", response.keys())
	
	if "data" in response:
		print("[BULK_RESPONSE] Campo 'data' encontrado, tamaño: ", response["data"].size())
		if response["data"].size() > 0:
			var image_data = response["data"][0]
			print("[BULK_RESPONSE] Datos de imagen: ", image_data.keys())
			
			# Verificar si tenemos URL (DALL-E 3) o b64_json (gpt-image-1)
			if "url" in image_data:
				var image_url = image_data["url"]
				print("[BULK_RESPONSE] URL de imagen obtenida: ", image_url)
				_download_image(image_url)
				return
			elif "b64_json" in image_data:
				var b64_data = image_data["b64_json"]
				print("[BULK_RESPONSE] Datos b64_json obtenidos, longitud: ", b64_data.length())
				_save_image_from_base64(b64_data)
				return
			else:
				print("[BULK_RESPONSE] ERROR: No se encontró campo 'url' ni 'b64_json' en datos de imagen")
		else:
			print("[BULK_RESPONSE] ERROR: Array 'data' vacío")
	else:
		print("[BULK_RESPONSE] ERROR: No se encontró campo 'data' en respuesta")
	
	print("[BULK_RESPONSE] ERROR: Respuesta de API inválida")
	status_label.text = "Error: Respuesta de API inválida"
	_finish_generation()

## Descarga la imagen generada
func _download_image(url: String) -> void:
	print("[BULK_DOWNLOAD] ========== DESCARGANDO IMAGEN ==========")
	print("[BULK_DOWNLOAD] URL: ", url)
	print("[BULK_DOWNLOAD] Timestamp: ", Time.get_unix_time_from_system())
	
	var image_http_request = HTTPRequest.new()
	add_child(image_http_request)
	image_http_request.connect("request_completed", _on_image_download_completed)
	
	print("[BULK_DOWNLOAD] HTTPRequest creado y conectado")
	
	var error = image_http_request.request(url)
	if error != OK:
		print("[BULK_DOWNLOAD] ERROR: Fallo al iniciar descarga (error: ", error, ")")
		status_label.text = "Error al descargar la imagen: " + str(error)
		image_http_request.queue_free()
		_continue_to_next_element()
	else:
		print("[BULK_DOWNLOAD] Descarga iniciada correctamente")

## Maneja la descarga completada de la imagen
func _on_image_download_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[BULK_DOWNLOAD] ========== DESCARGA COMPLETADA ==========")
	print("[BULK_DOWNLOAD] Result: ", result, " (", _get_http_request_error_description(result), ")")
	print("[BULK_DOWNLOAD] HTTP status: ", response_code)
	print("[BULK_DOWNLOAD] Body size: ", body.size(), " bytes")
	print("[BULK_DOWNLOAD] Timestamp: ", Time.get_unix_time_from_system())
	
	var image_http_request = get_children().filter(func(child): return child is HTTPRequest and child != http_request)[0]
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[BULK_DOWNLOAD] ERROR: Fallo en descarga - result: ", result, ", status: ", response_code)
		status_label.text = "Error al descargar la imagen: " + str(response_code)
		image_http_request.queue_free()
		_continue_to_next_element()
		return
	
	# Guardar la imagen con nombre descriptivo
	var current_element = elements_list[current_element_index]
	var safe_element_name = current_element.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	var timestamp = Time.get_unix_time_from_system()
	var file_name = output_folder + "/" + safe_element_name + "_" + str(timestamp) + ".png"
	
	print("[BULK_DOWNLOAD] Elemento: '", current_element, "'")
	print("[BULK_DOWNLOAD] Nombre seguro: '", safe_element_name, "'")
	print("[BULK_DOWNLOAD] Archivo destino: ", file_name)
	
	var image = Image.new()
	var load_error = image.load_png_from_buffer(body)
	if load_error != OK:
		print("[BULK_DOWNLOAD] ERROR: Fallo al procesar imagen PNG (error: ", load_error, ")")
		status_label.text = "Error al procesar la imagen: " + str(load_error)
		image_http_request.queue_free()
		_continue_to_next_element()
		return
	
	print("[BULK_DOWNLOAD] Imagen cargada correctamente")
	print("[BULK_DOWNLOAD] Tamaño de imagen: ", image.get_size())
	print("[BULK_DOWNLOAD] Formato: ", image.get_format())
	
	# Guardar la imagen en disco
	var save_error = image.save_png(file_name)
	if save_error != OK:
		print("[BULK_DOWNLOAD] ERROR: Fallo al guardar imagen en disco (error: ", save_error, ")")
		status_label.text = "Error al guardar la imagen: " + str(save_error)
	else:
		print("[BULK_DOWNLOAD] Imagen guardada exitosamente: ", file_name)
		
		# Verificar que el archivo se guardó correctamente
		var file_access = FileAccess.open(file_name, FileAccess.READ)
		if file_access:
			var file_size = file_access.get_length()
			file_access.close()
			print("[BULK_DOWNLOAD] Verificación: archivo guardado con tamaño ", file_size, " bytes")
		else:
			print("[BULK_DOWNLOAD] WARNING: No se pudo verificar el archivo guardado")
	
	# Continuar con el siguiente elemento
	image_http_request.queue_free()
	print("[BULK_DOWNLOAD] HTTPRequest liberado, continuando con siguiente elemento...")
	_continue_to_next_element()

## Continúa con el siguiente elemento
func _continue_to_next_element() -> void:
	print("[BULK_FLOW] Continuando con siguiente elemento...")
	current_element_index += 1
	print("[BULK_FLOW] Nuevo índice: ", current_element_index, " de ", elements_list.size())
	_generate_next_image()

## Finaliza el proceso de generación
func _finish_generation() -> void:
	print("[BULK_FINISH] ========== FINALIZANDO GENERACIÓN ==========")
	print("[BULK_FINISH] Timestamp: ", Time.get_datetime_string_from_system())
	print("[BULK_FINISH] Elementos procesados: ", current_element_index, " de ", elements_list.size())
	
	is_generating = false
	generate_button.disabled = false
	print("[BULK_FINISH] Interfaz rehabilitada")
	
	if current_element_index >= elements_list.size():
		print("[BULK_FINISH] ÉXITO: Todas las imágenes generadas")
		status_label.text = "Generación completada. " + str(elements_list.size()) + " imágenes generadas en bulk."
		# Actualizar el sistema de archivos para mostrar las nuevas imágenes
		print("[BULK_FINISH] Actualizando sistema de archivos...")
		EditorInterface.get_resource_filesystem().scan()
		print("[BULK_FINISH] Sistema de archivos actualizado")
	else:
		print("[BULK_FINISH] PARCIAL: Generación interrumpida")
		status_label.text = "Generación interrumpida. " + str(current_element_index) + " de " + str(elements_list.size()) + " imágenes generadas."
	
	progress_bar.visible = false
	print("[BULK_FINISH] Proceso finalizado")

## Guarda la imagen desde datos base64
func _save_image_from_base64(b64_data: String) -> void:
	print("[BULK_B64] ========== PROCESANDO IMAGEN BASE64 ==========")
	print("[BULK_B64] Longitud de datos: ", b64_data.length())
	print("[BULK_B64] Timestamp: ", Time.get_unix_time_from_system())
	
	# Decodificar base64
	var image_buffer = Marshalls.base64_to_raw(b64_data)
	if image_buffer.size() == 0:
		print("[BULK_B64] ERROR: Fallo al decodificar base64")
		status_label.text = "Error: Fallo al decodificar imagen base64"
		_continue_to_next_element()
		return
	
	print("[BULK_B64] Base64 decodificado, tamaño del buffer: ", image_buffer.size(), " bytes")
	
	# Crear imagen desde buffer
	var image = Image.new()
	var load_error = image.load_png_from_buffer(image_buffer)
	if load_error != OK:
		print("[BULK_B64] ERROR: Fallo al cargar imagen PNG desde buffer (error: ", load_error, ")")
		status_label.text = "Error al procesar la imagen: " + str(load_error)
		_continue_to_next_element()
		return
	
	print("[BULK_B64] Imagen cargada correctamente")
	print("[BULK_B64] Tamaño de imagen: ", image.get_size())
	print("[BULK_B64] Formato: ", image.get_format())
	
	# Generar nombre de archivo
	var current_element = elements_list[current_element_index]
	var safe_element_name = current_element.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	var timestamp = Time.get_unix_time_from_system()
	var file_name = output_folder + "/" + safe_element_name + "_" + str(timestamp) + ".png"
	
	print("[BULK_B64] Elemento: '", current_element, "'")
	print("[BULK_B64] Nombre seguro: '", safe_element_name, "'")
	print("[BULK_B64] Archivo destino: ", file_name)
	
	# Guardar la imagen en disco
	var save_error = image.save_png(file_name)
	if save_error != OK:
		print("[BULK_B64] ERROR: Fallo al guardar imagen en disco (error: ", save_error, ")")
		status_label.text = "Error al guardar la imagen: " + str(save_error)
	else:
		print("[BULK_B64] Imagen guardada exitosamente: ", file_name)
		
		# Verificar que el archivo se guardó correctamente
		var file_access = FileAccess.open(file_name, FileAccess.READ)
		if file_access:
			var file_size = file_access.get_length()
			file_access.close()
			print("[BULK_B64] Verificación: archivo guardado con tamaño ", file_size, " bytes")
		else:
			print("[BULK_B64] WARNING: No se pudo verificar el archivo guardado")
	
	# Continuar con el siguiente elemento
	print("[BULK_B64] Continuando con siguiente elemento...")
	_continue_to_next_element()