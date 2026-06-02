extends RefCounted

static var _cache: Dictionary = {}

static func load_texture(resource_path: String) -> Texture2D:
	if _cache.has(resource_path):
		return _cache[resource_path]
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[resource_path] = texture
	return texture
