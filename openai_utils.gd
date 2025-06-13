@tool
class_name OpenAIUtils

## Utilidades para el plugin de generación de imágenes con OpenAI

# Constantes de la API
const API_BASE_URL = "https://api.openai.com/v1"
const IMAGES_ENDPOINT = "/images/generations"
const MAX_PROMPT_LENGTH = 1000
const MIN_PROMPT_LENGTH = 10
const MAX_BATCH_SIZE = 10

# Modelos disponibles
enum ImageModel {
	GPT_IMAGE_1
}

# Tamaños de imagen soportados
enum ImageSize {
	SQUARE_1024,
	VERTICAL_1024,
	HORIZONTAL_1024
}

# Calidades disponibles
enum ImageQuality {
	HD,
	MEDIUM
}

# Tipos de fondo
enum BackgroundType {
	TRANSPARENT,
	COLOR
}

## Convierte el enum de modelo a string para la API
static func model_to_string(model: ImageModel) -> String:
	match model:
		ImageModel.GPT_IMAGE_1:
			return "gpt-image-1"
		_:
			return "gpt-image-1"

## Convierte el enum de tamaño a string para la API
static func size_to_string(size: ImageSize) -> String:
	match size:
		ImageSize.SQUARE_1024:
			return "1024x1024"
		ImageSize.VERTICAL_1024:
			return "1024x1792"
		ImageSize.HORIZONTAL_1024:
			return "1792x1024"
		_:
			return "1024x1024"

## Convierte el enum de calidad a string para la API
static func quality_to_string(quality: ImageQuality) -> String:
	match quality:
		ImageQuality.HD:
			return "hd"
		ImageQuality.MEDIUM:
			return "medium"
		_:
			return "medium"

## Convierte el enum de fondo a string para la API
static func background_to_string(background: BackgroundType) -> String:
	match background:
		BackgroundType.TRANSPARENT:
			return "transparent"
		BackgroundType.COLOR:
			return "color"
		_:
			return "transparent"

## Valida una API key de OpenAI
static func validate_api_key(api_key: String) -> bool:
	if api_key.is_empty():
		return false
	
	# Las API keys de OpenAI empiezan con "sk-" y tienen al menos 20 caracteres
	return api_key.begins_with("sk-") and api_key.length() > 20

## Valida un prompt
static func validate_prompt(prompt: String) -> Dictionary:
	var result = {"valid": false, "error": ""}
	
	if prompt.is_empty():
		result.error = "El prompt no puede estar vacío"
		return result
	
	if prompt.length() < MIN_PROMPT_LENGTH:
		result.error = "El prompt debe tener al menos " + str(MIN_PROMPT_LENGTH) + " caracteres"
		return result
	
	if prompt.length() > MAX_PROMPT_LENGTH:
		result.error = "El prompt no puede exceder " + str(MAX_PROMPT_LENGTH) + " caracteres"
		return result
	
	result.valid = true
	return result

## Genera un nombre de archivo único para una imagen
static func generate_filename(index: int, prefix: String = "image") -> String:
	var timestamp = Time.get_unix_time_from_system()
	return prefix + "_" + str(index) + "_" + str(timestamp) + ".png"

## Crea la estructura de directorios si no existe
static func ensure_directory_exists(path: String) -> bool:
	var dir = DirAccess.open("res://")
	if not dir:
		return false
	
	var relative_path = path.trim_prefix("res://")
	if not dir.dir_exists(relative_path):
		return dir.make_dir_recursive(relative_path) == OK
	
	return true

## Construye el payload JSON para la API de OpenAI
static func build_api_payload(prompt: String, model: ImageModel, size: ImageSize, quality: ImageQuality, background: BackgroundType) -> Dictionary:
	return {
		"model": model_to_string(model),
		"prompt": prompt,
		"n": 1,
		"size": size_to_string(size),
		"quality": quality_to_string(quality),
		"background": background_to_string(background)
	}

## Construye los headers para la API de OpenAI
static func build_api_headers(api_key: String) -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	])

## Parsea la respuesta de la API y extrae la URL de la imagen
static func parse_api_response(response_body: String) -> Dictionary:
	var result = {"success": false, "image_url": "", "error": ""}
	
	var json = JSON.new()
	var parse_result = json.parse(response_body)
	
	if parse_result != OK:
		result.error = "Error al parsear la respuesta JSON"
		return result
	
	var response = json.data
	
	if not response is Dictionary:
		result.error = "Respuesta de API inválida"
		return result
	
	if "error" in response:
		result.error = response.error.get("message", "Error desconocido de la API")
		return result
	
	if "data" in response and response.data is Array and response.data.size() > 0:
		var image_data = response.data[0]
		if "url" in image_data:
			result.success = true
			result.image_url = image_data.url
			return result
	
	result.error = "No se encontró URL de imagen en la respuesta"
	return result

## Obtiene el código de error HTTP como string descriptivo
static func get_http_error_message(code: int) -> String:
	match code:
		400:
			return "Solicitud inválida (400)"
		401:
			return "API Key inválida o expirada (401)"
		403:
			return "Acceso prohibido (403)"
		429:
			return "Límite de requests excedido (429)"
		500:
			return "Error interno del servidor (500)"
		502:
			return "Bad Gateway (502)"
		503:
			return "Servicio no disponible (503)"
		_:
			return "Error HTTP " + str(code)

## Prompts predefinidos útiles para juegos
static func get_preset_prompts() -> Dictionary:
	return {
		"character_front": "Front view character sprite, pixel art style, transparent background, game asset, clean design",
		"character_side": "Side view character sprite, pixel art style, transparent background, walking animation ready",
		"prop_isometric": "Isometric view game prop, cartoon style, bright colors, transparent background, 3D rendered",
		"ui_icon": "Game UI icon, clean modern design, 64x64, transparent background, minimalist style",
		"background_parallax": "2D game background layer, parallax scrolling ready, atmospheric lighting, detailed environment",
		"particle_effect": "Game particle effect sprite, transparent background, glowing effect, magical energy",
		"platform_tile": "2D platformer tile, seamless edges, cartoon style, bright colors, game environment",
		"enemy_sprite": "Enemy character sprite, front view, pixel art style, transparent background, game monster"
	}

## Configuraciones recomendadas para diferentes tipos de assets
static func get_recommended_settings(asset_type: String) -> Dictionary:
	match asset_type:
		"character":
			return {"size": ImageSize.SQUARE_1024, "quality": ImageQuality.HD, "background": BackgroundType.TRANSPARENT}
		"ui_icon":
			return {"size": ImageSize.SQUARE_1024, "quality": ImageQuality.MEDIUM, "background": BackgroundType.TRANSPARENT}
		"background":
			return {"size": ImageSize.HORIZONTAL_1024, "quality": ImageQuality.HD, "background": BackgroundType.COLOR}
		"prop":
			return {"size": ImageSize.SQUARE_1024, "quality": ImageQuality.MEDIUM, "background": BackgroundType.TRANSPARENT}
		_:
			return {"size": ImageSize.SQUARE_1024, "quality": ImageQuality.MEDIUM, "background": BackgroundType.TRANSPARENT}
