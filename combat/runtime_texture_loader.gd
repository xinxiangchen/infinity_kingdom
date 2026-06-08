extends RefCounted

static var _cache: Dictionary = {}

static func load_texture(resource_path: String) -> Texture2D:
	if _cache.has(resource_path):
		return _cache[resource_path]
	var source_texture := _load_source_image_texture(resource_path)
	if source_texture != null:
		_cache[resource_path] = source_texture
		return source_texture
	var packed_texture := ResourceLoader.load(resource_path) as Texture2D
	if packed_texture != null:
		_cache[resource_path] = packed_texture
		return packed_texture
	var texture := _load_source_image_texture(resource_path)
	if texture == null:
		return null
	_cache[resource_path] = texture
	return texture

static func _load_source_image_texture(resource_path: String) -> Texture2D:
	var extension := resource_path.get_extension().to_lower()
	if not ["png", "jpg", "jpeg", "webp"].has(extension):
		return null
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
